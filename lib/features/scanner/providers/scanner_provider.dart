// lib/features/scanner/providers/scanner_provider.dart
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
  // WHY: Track codes currently being processed to prevent duplicate DB queries
  // during rapid scanning before addBubble adds them to state.scannedCodes
  final Set<String> _processingCips = {};

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
      // WHY: rawValue is guaranteed non-null after the null check above
      final parsedData = Gs1Parser.parse(barcode.rawValue);
      final codeCip = parsedData.gtin;

      if (codeCip == null) {
        // WHY: Only log parsing failures, not every frame
        continue;
      }

      // WHY: Skip if already being processed to prevent duplicate DB queries
      // This prevents race condition where multiple frames trigger findMedicament
      // before addBubble adds the code to state.scannedCodes
      if (_processingCips.contains(codeCip)) {
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
        // WHY: Mark as processing immediately to prevent concurrent lookups
        _processingCips.add(codeCip);
        LoggerService.db(
          '[ScannerNotifier] Searching for medicament with CIP: $codeCip',
        );
        findMedicament(codeCip);
      }
    }
  }

  Future<bool> findMedicament(String codeCip) async {
    LoggerService.db('[ScannerNotifier] Querying database for CIP: $codeCip');

    try {
      final scanDao = ref.read(scanDaoProvider);
      final result = await scanDao.getProductByCip(codeCip);

      if (result != null) {
        // WHY: Log appropriate message based on product type
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
    } catch (e, stackTrace) {
      LoggerService.error(
        '[ScannerNotifier] Error querying database',
        e,
        stackTrace,
      );
      return false;
    } finally {
      // WHY: Always remove from processing set, even if error occurs
      // This ensures the lock is released so the code can be retried
      _processingCips.remove(codeCip);
    }
  }

  void addBubble(ScanBubble bubble) {
    final codeCip = bubble.cip;
    // WHY: Only block visual duplicates (items already shown as bubbles),
    // not items that were dismissed but still in scannedCodes history buffer.
    // This allows re-entry of dismissed items via manual entry.
    if (state.bubbles.any((b) => b.cip == codeCip)) return;

    final updatedCodes = Set<String>.from(state.scannedCodes)..add(codeCip);

    // WHY: Remove oldest bubble if we exceed max capacity.
    // New bubbles are inserted at index 0, so oldest is at the end.
    final updatedBubbles = List<ScanBubble>.from(state.bubbles);
    if (updatedBubbles.length >= _maxBubbles) {
      final oldest = updatedBubbles.removeLast();
      final oldestCode = oldest.cip;
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
    updatedBubbles.insert(0, bubble);

    state = state.copyWith(bubbles: updatedBubbles, scannedCodes: updatedCodes);
  }

  void removeBubble(String codeCip) {
    final index = state.bubbles.indexWhere((bubble) => bubble.cip == codeCip);
    if (index == -1) return;

    final updatedBubbles = List<ScanBubble>.from(state.bubbles);
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
}
