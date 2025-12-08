import 'dart:async';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/models/scan_result.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/utils/gs1_parser.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'scanner_provider.g.dart';
part 'scanner_provider.mapper.dart';

typedef ScanBubble = ScanResult;

enum ScannerMode {
  analysis,
  restock,
}

enum ScannerHapticType {
  success,
  warning,
  error,
}

sealed class ScannerSideEffect {
  const ScannerSideEffect();
}

class ScannerToast extends ScannerSideEffect {
  const ScannerToast(this.message);
  final String message;
}

class ScannerDuplicateDetected extends ScannerSideEffect {
  const ScannerDuplicateDetected(this.duplicate);
  final DuplicateScanEvent duplicate;
}

class ScannerHaptic extends ScannerSideEffect {
  const ScannerHaptic(this.type);
  final ScannerHapticType type;
}

class ScannerRuntime {
  final Map<String, Timer> dismissTimers = {};
  final Map<String, DateTime> scanCooldowns = {};
  final Set<String> processingCips = {};
  Timer? cleanupTimer;
  String? pendingCleanupCode;

  void dispose() {
    for (final timer in dismissTimers.values) {
      timer.cancel();
    }
    dismissTimers.clear();
    cleanupTimer?.cancel();
    processingCips.clear();
    scanCooldowns.clear();
    pendingCleanupCode = null;
  }
}

@Riverpod(keepAlive: true)
ScannerRuntime scannerRuntime(Ref ref) {
  final runtime = ScannerRuntime();
  ref.onDispose(runtime.dispose);
  return runtime;
}

@MappableClass()
class ScannerState with ScannerStateMappable {
  const ScannerState({
    required this.bubbles,
    required this.scannedCodes,
    required this.mode,
  });

  final List<ScanBubble> bubbles;
  final Set<String> scannedCodes;
  final ScannerMode mode;
}

class DuplicateScanEvent {
  const DuplicateScanEvent({
    required this.cip,
    required this.serial,
    required this.productName,
    required this.currentQuantity,
  });

  final String cip;
  final String serial;
  final String productName;
  final int currentQuantity;
}

@Riverpod(keepAlive: true)
class ScannerNotifier extends _$ScannerNotifier {
  static const int _maxBubbles = AppConfig.scannerHistoryLimit;
  static const Duration _bubbleLifetime = AppConfig.scannerBubbleLifetime;
  static const Duration _codeCleanupDelay = AppConfig.scannerCodeCleanupDelay;
  static const Duration _codeRemovalDelay = Duration(seconds: 3);
  static const Duration _cooldownDuration = Duration(seconds: 2);
  static const Duration _cooldownCleanupThreshold = Duration(minutes: 5);

  final _sideEffects = StreamController<ScannerSideEffect>.broadcast(
    sync: true,
  );
  ScannerRuntime? _cachedRuntime;

  ScannerRuntime get _runtime {
    final runtime = _cachedRuntime;
    if (runtime != null) return runtime;
    final created = ref.read(scannerRuntimeProvider);
    _cachedRuntime = created;
    return created;
  }

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
      final runtime = _cachedRuntime;
      runtime?.dispose();
      unawaited(_sideEffects.close());
    });

    return _initialState;
  }

  Stream<ScannerSideEffect> get sideEffects => _sideEffects.stream;

  void setMode(ScannerMode mode) {
    final current = _currentState;
    state = AsyncData(current.copyWith(mode: mode));
  }

  Future<void> processBarcodeCapture(
    BarcodeCapture capture, {
    bool force = false,
  }) async {
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

      if (force &&
          _currentState.bubbles.any((b) => b.cip.toString() == codeCip)) {
        removeBubble(codeCip);
      }

      final scanKey = _getUniqueScanKey(codeCip, parsedData.serial);
      final now = DateTime.now();

      if (!force && _isCooldownActive(scanKey, now)) {
        continue;
      }
      _cleanupExpiredCooldowns(now);
      _runtime.scanCooldowns[scanKey] = now;

      if (_runtime.processingCips.contains(codeCip)) {
        continue;
      }

      final rawValuePreview = barcode.rawValue!.length > 50
          ? '${barcode.rawValue!.substring(0, 50)}...'
          : barcode.rawValue!;
      LoggerService.debug(
        '[ScannerNotifier] Barcode detected - Format: ${barcode.format}, '
        'GTIN: $codeCip, RawValue: $rawValuePreview, Force: $force',
      );

      if (mode == ScannerMode.analysis) {
        await _handleAnalysisScan(
          codeCip: codeCip,
          force: force,
          expDate: parsedData.expDate,
        );
      } else {
        await _handleRestockScan(parsedData);
      }

      if (!ref.mounted) {
        return;
      }
    }
  }

  Future<void> _handleAnalysisScan({
    required String codeCip,
    required bool force,
    required DateTime? expDate,
  }) async {
    final currentState = _currentState;

    if (!force && currentState.scannedCodes.contains(codeCip)) {
      return;
    }

    if (force && currentState.bubbles.any((b) => b.cip.toString() == codeCip)) {
      removeBubble(codeCip);
    }

    LoggerService.db(
      '[ScannerNotifier] Searching for medicament with CIP: $codeCip (force: $force)',
    );
    await findMedicament(
      codeCip,
      force: force,
      expDate: expDate,
    );
    if (!ref.mounted) return;
  }

  Future<void> _handleRestockScan(Gs1DataMatrix parsedData) async {
    final codeCip = parsedData.gtin;
    if (codeCip == null) {
      return;
    }

    if (_runtime.processingCips.contains(codeCip)) {
      return;
    }
    _runtime.processingCips.add(codeCip);

    try {
      final cip13 = Cip13.validated(codeCip);
      final catalogDao = ref.read(catalogDaoProvider);
      final db = ref.read(appDatabaseProvider);
      final restockDao = db.restockDao;

      final result = await catalogDao.getProductByCip(cip13);
      if (!ref.mounted) return;
      if (result == null) {
        LoggerService.warning(
          '[ScannerNotifier] Restock mode: no product found for CIP: $codeCip',
        );
        _emit(const ScannerHaptic(ScannerHapticType.error));
        return;
      }

      final serial = parsedData.serial;
      if (serial != null &&
          await restockDao.isDuplicate(cip: codeCip, serial: serial)) {
        if (!ref.mounted) return;
        final currentQuantity =
            await restockDao.getRestockQuantity(codeCip) ?? 1;
        if (!ref.mounted) return;
        _emit(
          ScannerDuplicateDetected(
            DuplicateScanEvent(
              cip: codeCip,
              serial: serial,
              productName: result.summary.data.nomCanonique,
              currentQuantity: currentQuantity,
            ),
          ),
        );
        _emit(const ScannerHaptic(ScannerHapticType.warning));
        return;
      }

      final outcome = await restockDao.addUniqueBox(
        cip: cip13,
        serial: serial,
        batchNumber: parsedData.lot,
        expiryDate: parsedData.expDate,
      );
      if (!ref.mounted) return;

      if (outcome == ScanOutcome.added) {
        _emit(const ScannerHaptic(ScannerHapticType.success));
      } else {
        _emit(const ScannerHaptic(ScannerHapticType.warning));
      }

      final label = result.summary.data.nomCanonique;
      final message = switch (outcome) {
        ScanOutcome.added => '+1 $label',
        ScanOutcome.duplicate =>
          parsedData.serial != null
              ? Strings.duplicateSerial(parsedData.serial!)
              : Strings.duplicateSerialUnknown,
      };
      _emit(ScannerToast(message));
    } finally {
      _runtime.processingCips.remove(codeCip);
    }
  }

  Future<bool> findMedicament(
    String codeCip, {
    bool force = false,
    DateTime? expDate,
  }) async {
    if (_runtime.processingCips.contains(codeCip)) {
      return false;
    }
    _runtime.processingCips.add(codeCip);

    LoggerService.db('[ScannerNotifier] Querying database for CIP: $codeCip');

    var found = false;

    try {
      final previousState = _currentState;
      final guarded = await AsyncValue.guard<ScannerState>(() async {
        final cip13 = Cip13.validated(codeCip);
        final catalogDao = ref.read(catalogDaoProvider);
        final result = await catalogDao.getProductByCip(
          cip13,
          expDate: expDate,
        );
        if (!ref.mounted) {
          return previousState;
        }

        if (result != null) {
          if (result.summary.groupId != null) {
            if (result.summary.data.isPrinceps) {
              LoggerService.info(
                '[ScannerNotifier] Princeps medication found: ${result.summary.data.nomCanonique} '
                '(Princeps de ce groupe)',
              );
            } else {
              final reference =
                  result.summary.data.princepsDeReference.isNotEmpty
                  ? result.summary.data.princepsDeReference
                  : 'groupe ${result.summary.groupId}';
              LoggerService.info(
                '[ScannerNotifier] Generic medication found: ${result.summary.data.nomCanonique} '
                '(Générique de $reference)',
              );
            }
          } else {
            LoggerService.info(
              '[ScannerNotifier] Standalone medication found: ${result.summary.data.nomCanonique} '
              '(Médicament Unique)',
            );
          }

          if (result.availabilityStatus != null &&
              result.availabilityStatus!.isNotEmpty) {
            _emit(const ScannerHaptic(ScannerHapticType.warning));
          } else {
            _emit(const ScannerHaptic(ScannerHapticType.success));
          }

          found = true;
          addBubble(result);
          return _currentState;
        } else {
          LoggerService.warning(
            '[ScannerNotifier] No product found in database for CIP: $codeCip',
          );
          _emit(const ScannerHaptic(ScannerHapticType.error));
          return previousState;
        }
      });

      if (!ref.mounted) {
        return found;
      }
      state = guarded;
      return found;
    } finally {
      _runtime.processingCips.remove(codeCip);
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
      _runtime.dismissTimers[codeCip]?.cancel();
      updatedBubbles.removeAt(existingIndex);
    }

    final updatedCodes = Set<String>.from(currentState.scannedCodes)
      ..add(codeCip);
    if (updatedBubbles.length >= _maxBubbles) {
      final oldest = updatedBubbles.removeLast();
      final oldestCode = oldest.cip.toString();
      _runtime.dismissTimers[oldestCode]?.cancel();
      _runtime.dismissTimers.remove(oldestCode);

      _runtime.cleanupTimer?.cancel();
      _runtime.pendingCleanupCode = oldestCode;
      _runtime.cleanupTimer = Timer(_codeCleanupDelay, () {
        if (_runtime.pendingCleanupCode == oldestCode) {
          final latestState = _currentState;
          final currentCodes = Set<String>.from(latestState.scannedCodes)
            ..remove(oldestCode);
          state = AsyncData(
            latestState.copyWith(scannedCodes: currentCodes),
          );
          _runtime.pendingCleanupCode = null;
        }
      });
    }

    final timer = Timer(_bubbleLifetime, () => removeBubble(codeCip));
    _runtime.dismissTimers[codeCip] = timer;

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

    _runtime.dismissTimers[codeCip]?.cancel();
    _runtime.dismissTimers.remove(codeCip);

    state = AsyncData(
      currentState.copyWith(bubbles: updatedBubbles),
    );

    Timer(_codeRemovalDelay, () {
      if (!ref.mounted) return;
      final latestState = _currentState;
      final currentCodes = Set<String>.from(latestState.scannedCodes)
        ..remove(codeCip);
      state = AsyncData(
        latestState.copyWith(scannedCodes: currentCodes),
      );
    });
  }

  void clearAllBubbles() {
    for (final timer in _runtime.dismissTimers.values) {
      timer.cancel();
    }
    _runtime.dismissTimers.clear();
    _runtime.cleanupTimer?.cancel();
    _runtime.pendingCleanupCode = null;
    _runtime.scanCooldowns.clear();

    state = const AsyncData(_initialState);
  }

  Future<void> updateQuantityFromDuplicate(String cip, int newQuantity) async {
    final db = ref.read(appDatabaseProvider);
    await db.restockDao.forceUpdateQuantity(
      cip: cip,
      newQuantity: newQuantity,
    );
    if (!ref.mounted) return;
    _emit(const ScannerHaptic(ScannerHapticType.success));
  }

  void _emit(ScannerSideEffect effect) {
    if (_sideEffects.isClosed) return;
    _sideEffects.add(effect);
  }

  String _getUniqueScanKey(String cip, String? serial) {
    if (serial == null || serial.isEmpty) return cip;
    return '$cip::$serial';
  }

  void _cleanupExpiredCooldowns(DateTime now) {
    _runtime.scanCooldowns.removeWhere(
      (_, lastSeen) => now.difference(lastSeen) > _cooldownCleanupThreshold,
    );
  }

  bool _isCooldownActive(String scanKey, DateTime now) {
    final lastScan = _runtime.scanCooldowns[scanKey];
    if (lastScan == null) return false;
    return now.difference(lastScan) < _cooldownDuration;
  }
}
