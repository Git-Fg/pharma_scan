import 'dart:async';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/models/scan_result.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/utils/gs1_parser.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'scanner_provider.g.dart';

typedef ScanBubble = ScanResult;

class ScannerState {
  const ScannerState({required this.bubbles, required this.scannedCodes});

  final List<ScanBubble> bubbles;
  final Set<String> scannedCodes;

  ScannerState copyWith({
    List<ScanBubble>? bubbles,
    Set<String>? scannedCodes,
  }) {
    return ScannerState(
      bubbles: bubbles ?? this.bubbles,
      scannedCodes: scannedCodes ?? this.scannedCodes,
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
  String? _lastProcessedCode;
  final Set<String> _processingCips = {};

  @override
  ScannerState build() {
    ref.onDispose(() {
      for (final timer in _dismissTimers.values) {
        timer.cancel();
      }
      _dismissTimers.clear();
      _cleanupTimer?.cancel();
    });

    return const ScannerState(bubbles: [], scannedCodes: {});
  }

  void processBarcodeCapture(
    BarcodeCapture capture, {
    bool force = false,
  }) {
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

      // Skip duplicate check if force is true
      if (!force && state.scannedCodes.contains(codeCip)) {
        continue;
      }

      // If force is true and bubble exists, remove it first (will be re-added at top)
      if (force && state.bubbles.any((b) => b.cip == codeCip)) {
        removeBubble(codeCip);
      }

      if (isNewCode) {
        LoggerService.db(
          '[ScannerNotifier] Searching for medicament with CIP: $codeCip (force: $force)',
        );
        unawaited(findMedicament(codeCip, force: force));
      }
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

    try {
      final catalogDao = ref.read(catalogDaoProvider);
      final result = await catalogDao.getProductByCip(codeCip);

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

        addBubble(result);
        return true;
      } else {
        LoggerService.warning(
          '[ScannerNotifier] No product found in database for CIP: $codeCip',
        );
        return false;
      }
    } on Exception catch (e, stackTrace) {
      LoggerService.error(
        '[ScannerNotifier] Error querying database for CIP: $codeCip',
        e,
        stackTrace,
      );
      return false;
    } finally {
      _processingCips.remove(codeCip);
    }
  }

  void addBubble(ScanBubble bubble) {
    final codeCip = bubble.cip;

    // Remove existing bubble if it exists (for bump-to-top behavior)
    final existingIndex = state.bubbles.indexWhere((b) => b.cip == codeCip);
    final updatedBubbles = List<ScanBubble>.from(state.bubbles);

    if (existingIndex != -1) {
      // Cancel existing timer
      _dismissTimers[codeCip]?.cancel();
      // Remove from list (will be re-inserted at top)
      updatedBubbles.removeAt(existingIndex);
    }

    final updatedCodes = Set<String>.from(state.scannedCodes)..add(codeCip);
    if (updatedBubbles.length >= _maxBubbles) {
      final oldest = updatedBubbles.removeLast();
      final oldestCode = oldest.cip;
      _dismissTimers[oldestCode]?.cancel();
      _dismissTimers.remove(oldestCode);

      _cleanupTimer?.cancel();
      _cleanupTimer = Timer(_codeCleanupDelay, () {
        final currentCodes = Set<String>.from(state.scannedCodes)
          ..remove(oldestCode);
        state = state.copyWith(scannedCodes: currentCodes);
      });
    }

    final timer = Timer(_bubbleLifetime, () => removeBubble(codeCip));
    _dismissTimers[codeCip] = timer;

    // Insert at top (index 0)
    updatedBubbles.insert(0, bubble);

    state = state.copyWith(bubbles: updatedBubbles, scannedCodes: updatedCodes);
  }

  void removeBubble(String codeCip) {
    final index = state.bubbles.indexWhere((bubble) => bubble.cip == codeCip);
    if (index == -1) return;

    final updatedBubbles = List<ScanBubble>.from(state.bubbles)
      ..removeAt(index);

    _dismissTimers[codeCip]?.cancel();
    _dismissTimers.remove(codeCip);

    state = state.copyWith(bubbles: updatedBubbles);

    Timer(_codeRemovalDelay, () {
      final currentCodes = Set<String>.from(state.scannedCodes)
        ..remove(codeCip);
      state = state.copyWith(scannedCodes: currentCodes);
    });
  }

  void clearAllBubbles() {
    for (final timer in _dismissTimers.values) {
      timer.cancel();
    }
    _dismissTimers.clear();
    _cleanupTimer?.cancel();

    state = const ScannerState(bubbles: [], scannedCodes: {});
  }
}
