import 'dart:async';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/models/scan_result.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/utils/gs1_parser.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'scanner_provider.g.dart';

typedef ScanBubble = ScanResult;

enum ScannerMode {
  analysis,
  restock,
}

class ScannerState {
  const ScannerState({
    required this.bubbles,
    required this.scannedCodes,
    required this.mode,
    this.lastRestockMessage,
  });

  final List<ScanBubble> bubbles;
  final Set<String> scannedCodes;
  final ScannerMode mode;
  final String? lastRestockMessage;

  ScannerState copyWith({
    List<ScanBubble>? bubbles,
    Set<String>? scannedCodes,
    ScannerMode? mode,
    String? lastRestockMessage,
  }) {
    return ScannerState(
      bubbles: bubbles ?? this.bubbles,
      scannedCodes: scannedCodes ?? this.scannedCodes,
      mode: mode ?? this.mode,
      lastRestockMessage: lastRestockMessage ?? this.lastRestockMessage,
    );
  }
}

@riverpod
class ScannerNotifier extends _$ScannerNotifier {
  static const int _maxBubbles = AppConfig.scannerHistoryLimit;
  static const Duration _bubbleLifetime = AppConfig.scannerBubbleLifetime;
  static const Duration _codeCleanupDelay = AppConfig.scannerCodeCleanupDelay;
  static const Duration _codeRemovalDelay = Duration(seconds: 3);

  final Map<String, Timer> _dismissTimers = {};
  Timer? _cleanupTimer;
  String? _pendingCleanupCode;
  String? _lastProcessedCode;
  final Set<String> _processingCips = {};

  static const ScannerState _initialState = ScannerState(
    bubbles: [],
    scannedCodes: {},
    mode: ScannerMode.analysis,
  );

  ScannerState get _currentState =>
      state.maybeWhen(data: (value) => value, orElse: () => _initialState);

  @override
  FutureOr<ScannerState> build() {
    ref.onDispose(() {
      for (final timer in _dismissTimers.values) {
        timer.cancel();
      }
      _dismissTimers.clear();
      _cleanupTimer?.cancel();
      _pendingCleanupCode = null;
    });

    return _initialState;
  }

  void setMode(ScannerMode mode) {
    final current = _currentState;
    state = AsyncData(current.copyWith(mode: mode));
  }

  void processBarcodeCapture(
    BarcodeCapture capture, {
    bool force = false,
  }) {
    final mode = _currentState.mode;

    for (final barcode in capture.barcodes) {
      if (barcode.rawValue == null) {
        continue;
      }

      final parsedData = Gs1Parser.parse(barcode.rawValue);
      final codeCip = parsedData.gtin;

      if (codeCip == null) {
        continue;
      }

      if (_processingCips.contains(codeCip)) {
        continue;
      }

      final isNewCode = codeCip != _lastProcessedCode;
      if (isNewCode) {
        _lastProcessedCode = codeCip;
        final rawValuePreview = barcode.rawValue!.length > 50
            ? '${barcode.rawValue!.substring(0, 50)}...'
            : barcode.rawValue!;
        LoggerService.debug(
          '[ScannerNotifier] New barcode detected - Format: ${barcode.format}, '
          'GTIN: $codeCip, RawValue: $rawValuePreview, Force: $force',
        );
      }

      if (mode == ScannerMode.analysis) {
        final currentState = _currentState;

        if (!force && currentState.scannedCodes.contains(codeCip)) {
          continue;
        }

        if (force &&
            currentState.bubbles.any((b) => b.cip.toString() == codeCip)) {
          removeBubble(codeCip);
        }

        if (isNewCode) {
          LoggerService.db(
            '[ScannerNotifier] Searching for medicament with CIP: $codeCip (force: $force)',
          );
          unawaited(findMedicament(codeCip, force: force));
        }
      } else {
        unawaited(_restockMedicament(codeCip));
      }
    }
  }

  Future<void> _restockMedicament(String codeCip) async {
    if (_processingCips.contains(codeCip)) {
      return;
    }
    _processingCips.add(codeCip);

    try {
      final cip13 = Cip13.validated(codeCip);
      final catalogDao = ref.read(catalogDaoProvider);
      final db = ref.read(appDatabaseProvider);
      final restockDao = db.restockDao;
      final haptics = ref.read(hapticServiceProvider);
      final hapticSettings = ref.read(hapticSettingsProvider);
      final canVibrate = hapticSettings.maybeWhen(
        data: (value) => value,
        orElse: () => true,
      );

      final result = await catalogDao.getProductByCip(cip13);
      if (result == null) {
        LoggerService.warning(
          '[ScannerNotifier] Restock mode: no product found for CIP: $codeCip',
        );
        if (canVibrate) {
          await haptics.error();
        }
        return;
      }

      await restockDao.addToRestock(cip13);

      if (canVibrate) {
        await haptics.success();
      }

      final label = result.summary.nomCanonique;
      final message = '+1 $label';
      final current = _currentState;
      state = AsyncData(
        current.copyWith(lastRestockMessage: message),
      );
    } finally {
      _processingCips.remove(codeCip);
    }
  }

  Future<bool> findMedicament(
    String codeCip, {
    bool force = false,
  }) async {
    if (_processingCips.contains(codeCip)) {
      return false;
    }
    _processingCips.add(codeCip);

    LoggerService.db('[ScannerNotifier] Querying database for CIP: $codeCip');

    var found = false;

    try {
      final previousState = _currentState;
      final guarded = await AsyncValue.guard<ScannerState>(() async {
        final cip13 = Cip13.validated(codeCip);
        final catalogDao = ref.read(catalogDaoProvider);
        final result = await catalogDao.getProductByCip(cip13);

        final haptics = ref.read(hapticServiceProvider);
        final hapticSettings = ref.read(hapticSettingsProvider);
        final canVibrate = hapticSettings.maybeWhen(
          data: (value) => value,
          orElse: () => true,
        );

        if (result != null) {
          if (result.summary.groupId != null) {
            if (result.summary.isPrinceps) {
              LoggerService.info(
                '[ScannerNotifier] Princeps medication found: ${result.summary.nomCanonique} '
                '(Princeps de ce groupe)',
              );
            } else {
              final reference = result.summary.princepsDeReference.isNotEmpty
                  ? result.summary.princepsDeReference
                  : 'groupe ${result.summary.groupId}';
              LoggerService.info(
                '[ScannerNotifier] Generic medication found: ${result.summary.nomCanonique} '
                '(Générique de $reference)',
              );
            }
          } else {
            LoggerService.info(
              '[ScannerNotifier] Standalone medication found: ${result.summary.nomCanonique} '
              '(Médicament Unique)',
            );
          }

          if (canVibrate) {
            if (result.availabilityStatus != null &&
                result.availabilityStatus!.isNotEmpty) {
              await haptics.warning();
            } else {
              await haptics.success();
            }
          }

          found = true;
          addBubble(result);
          return _currentState;
        } else {
          LoggerService.warning(
            '[ScannerNotifier] No product found in database for CIP: $codeCip',
          );
          if (canVibrate) {
            await haptics.error();
          }
          return previousState;
        }
      });

      state = guarded;
      return found;
    } finally {
      _processingCips.remove(codeCip);
    }
  }

  void addBubble(ScanBubble bubble) {
    final codeCip = bubble.cip.toString();
    final currentState = _currentState;

    final existingIndex = currentState.bubbles.indexWhere(
      (b) => b.cip.toString() == codeCip,
    );
    final updatedBubbles = List<ScanBubble>.from(currentState.bubbles);

    if (existingIndex != -1) {
      _dismissTimers[codeCip]?.cancel();
      updatedBubbles.removeAt(existingIndex);
    }

    final updatedCodes = Set<String>.from(currentState.scannedCodes)
      ..add(codeCip);
    if (updatedBubbles.length >= _maxBubbles) {
      final oldest = updatedBubbles.removeLast();
      final oldestCode = oldest.cip.toString();
      _dismissTimers[oldestCode]?.cancel();
      _dismissTimers.remove(oldestCode);

      _cleanupTimer?.cancel();
      _pendingCleanupCode = oldestCode;
      _cleanupTimer = Timer(_codeCleanupDelay, () {
        if (_pendingCleanupCode == oldestCode) {
          final latestState = _currentState;
          final currentCodes = Set<String>.from(latestState.scannedCodes)
            ..remove(oldestCode);
          state = AsyncData(
            latestState.copyWith(scannedCodes: currentCodes),
          );
          _pendingCleanupCode = null;
        }
      });
    }

    final timer = Timer(_bubbleLifetime, () => removeBubble(codeCip));
    _dismissTimers[codeCip] = timer;

    updatedBubbles.insert(0, bubble);

    state = AsyncData(
      currentState.copyWith(
        bubbles: updatedBubbles,
        scannedCodes: updatedCodes,
      ),
    );
  }

  void removeBubble(String codeCip) {
    final currentState = _currentState;
    final index = currentState.bubbles.indexWhere(
      (bubble) => bubble.cip == codeCip,
    );
    if (index == -1) return;

    final updatedBubbles = List<ScanBubble>.from(currentState.bubbles)
      ..removeAt(index);

    _dismissTimers[codeCip]?.cancel();
    _dismissTimers.remove(codeCip);

    state = AsyncData(
      currentState.copyWith(bubbles: updatedBubbles),
    );

    Timer(_codeRemovalDelay, () {
      final latestState = _currentState;
      final currentCodes = Set<String>.from(latestState.scannedCodes)
        ..remove(codeCip);
      state = AsyncData(
        latestState.copyWith(scannedCodes: currentCodes),
      );
    });
  }

  void clearAllBubbles() {
    for (final timer in _dismissTimers.values) {
      timer.cancel();
    }
    _dismissTimers.clear();
    _cleanupTimer?.cancel();
    _pendingCleanupCode = null;

    state = const AsyncData(_initialState);
  }
}
