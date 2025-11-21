// lib/features/scanner/providers/scanner_provider.dart
import 'dart:async';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/providers/repositories_providers.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/utils/gs1_parser.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'scanner_provider.g.dart';

class ScannerState {
  const ScannerState({required this.bubbles, required this.scannedCodes});

  final List<ScanResult> bubbles;
  final Set<String> scannedCodes;

  ScannerState copyWith({
    List<ScanResult>? bubbles,
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

  @override
  ScannerState build() {
    // WHY: Cancel all timers when the provider is disposed to prevent memory leaks.
    ref.onDispose(() {
      for (final timer in _dismissTimers.values) {
        timer.cancel();
      }
      _dismissTimers.clear();
      _cleanupTimer?.cancel();
    });

    return const ScannerState(bubbles: [], scannedCodes: {});
  }

  void processBarcodeCapture(BarcodeCapture capture) {
    // WHY: Only log when processing a new code to avoid flooding logs in high-frequency streams
    // (e.g., MobileScanner can emit captures multiple times per second)

    for (final barcode in capture.barcodes) {
      if (barcode.rawValue == null) {
        // WHY: Only log null rawValue warnings, not debug every frame
        continue;
      }

      // 1. Parser le code GS1
      final parsedData = Gs1Parser.parse(barcode.rawValue);
      final codeCip = parsedData.gtin;

      if (codeCip == null) {
        // WHY: Only log parsing failures, not every frame
        continue;
      }

      // WHY: Only log when we detect a new code that we haven't processed yet
      final isNewCode = codeCip != _lastProcessedCode;
      if (isNewCode) {
        _lastProcessedCode = codeCip;
        final rawValuePreview = barcode.rawValue!.length > 50
            ? '${barcode.rawValue!.substring(0, 50)}...'
            : barcode.rawValue!;
        LoggerService.debug(
          '[ScannerNotifier] New barcode detected - Format: ${barcode.format}, '
          'GTIN: $codeCip, RawValue: $rawValuePreview',
        );
      }

      if (state.scannedCodes.contains(codeCip)) {
        // WHY: Skip silently if already scanned - user can see it in the UI
        continue;
      }

      // 2. Interroger la base de données
      if (isNewCode) {
        LoggerService.db(
          '[ScannerNotifier] Searching for medicament with CIP: $codeCip',
        );
      }
      findMedicament(codeCip);
    }
  }

  Future<bool> findMedicament(String codeCip) async {
    LoggerService.db('[ScannerNotifier] Querying database for CIP: $codeCip');

    try {
      final repository = ref.read(scannerRepositoryProvider);
      final scanResult = await repository.getScanResult(codeCip);

      if (scanResult != null) {
        LoggerService.info(
          '[ScannerNotifier] Scan result received, updating bubble queue',
        );
        addBubble(scanResult);
        return true;
      } else {
        LoggerService.warning(
          '[ScannerNotifier] No medicament found in database for CIP: $codeCip',
        );
        return false;
      }
    } catch (e, stackTrace) {
      LoggerService.error(
        '[ScannerNotifier] Error querying database',
        e,
        stackTrace,
      );
      return false;
    }
  }

  void addBubble(ScanResult scanResult) {
    final codeCip = _codeFromResult(scanResult);
    if (state.scannedCodes.contains(codeCip)) return;

    final updatedCodes = Set<String>.from(state.scannedCodes)..add(codeCip);

    // WHY: Remove oldest bubble if we exceed max capacity.
    // New bubbles are inserted at index 0, so oldest is at the end.
    final updatedBubbles = List<ScanResult>.from(state.bubbles);
    if (updatedBubbles.length >= _maxBubbles) {
      final oldest = updatedBubbles.removeLast();
      final oldestCode = _codeFromResult(oldest);
      _dismissTimers[oldestCode]?.cancel();
      _dismissTimers.remove(oldestCode);

      // WHY: Delay cleanup of scanned code to allow re-scanning after a short period.
      _cleanupTimer?.cancel();
      _cleanupTimer = Timer(_codeCleanupDelay, () {
        // WHY: State update is safe even if provider is disposed - it will be a no-op.
        final currentCodes = Set<String>.from(state.scannedCodes);
        currentCodes.remove(oldestCode);
        state = state.copyWith(scannedCodes: currentCodes);
      });
    }

    // WHY: Create auto-dismiss timer for the new bubble.
    final timer = Timer(_bubbleLifetime, () => removeBubble(codeCip));
    _dismissTimers[codeCip] = timer;

    // WHY: Insert at index 0 so newest bubble appears at the top.
    updatedBubbles.insert(0, scanResult);

    state = state.copyWith(bubbles: updatedBubbles, scannedCodes: updatedCodes);
  }

  void removeBubble(String codeCip) {
    final index = state.bubbles.indexWhere(
      (bubble) => _codeFromResult(bubble) == codeCip,
    );
    if (index == -1) return;

    final updatedBubbles = List<ScanResult>.from(state.bubbles);
    updatedBubbles.removeAt(index);

    _dismissTimers[codeCip]?.cancel();
    _dismissTimers.remove(codeCip);

    state = state.copyWith(bubbles: updatedBubbles);

    // WHY: Delay removal of scanned code to allow re-scanning after a short period.
    Timer(_codeRemovalDelay, () {
      // WHY: State update is safe even if provider is disposed - it will be a no-op.
      final currentCodes = Set<String>.from(state.scannedCodes);
      currentCodes.remove(codeCip);
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

  String _codeFromResult(ScanResult scanResult) {
    return scanResult.map(
      generic: (value) => value.medicament.codeCip,
      princeps: (value) => value.princeps.codeCip,
      standalone: (value) => value.medicament.codeCip,
    );
  }
}
