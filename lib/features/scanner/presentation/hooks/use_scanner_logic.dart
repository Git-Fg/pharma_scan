import 'dart:async';
import 'package:pharma_scan/core/models/scan_models.dart';
import 'package:pharma_scan/features/scanner/logic/scanner_store.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Flutter Hook that provides ScannerStore instance and lifecycle management
///
/// This hook demonstrates the Triad Architecture:
/// - Riverpod: ScannerNotifier for global state (database, medication search)
/// - Flutter Hooks: Widget lifecycle and state management
/// - Dart Signals: High-frequency local state for 60fps performance
///
/// Usage:
/// ```dart
/// class MyWidget extends HookConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final scannerLogic = useScannerLogic(ref);
///
///     // Access signals for optimal performance
///     return Watch((_) => Text('Bubbles: ${scannerLogic.store.bubbleCount.value}'));
///   }
/// }
ScannerLogic useScannerLogic(WidgetRef ref) {
  final store = useMemoized(() => ScannerStore());

  // Watch notifier for persistence and read the provider once for initial state
  final scannerNotifier = ref.read(scannerProvider.notifier);

  useEffect(() {
    // Sync: Listen to ScannerNotifier side effects to populate the local store
    final subscription = scannerNotifier.sideEffects.listen((effect) {
      if (effect is ScannerResultFound) {
        // Directly add to Signals store without triggering new search
        store.addScan(effect.result);
      }
    });

    return subscription.cancel;
  }, [scannerNotifier]);

  // Cleanup when hook is disposed
  useEffect(() {
    return () {
      store.dispose();
    };
  }, [store]);

  // Bridge between Signals local state and Riverpod global state
  void handleScanResult(ScanResult result) {
    // Add to Signals store for high-frequency UI updates
    store.addScan(result);

    // Fire-and-forget: Let Riverpod handle persistence/business logic
    // Do not wait for Riverpod to update the UI — Signals remains the UI source of truth
    unawaited(scannerNotifier.findMedicament(result.cip.toString()));
  }

  void removeBubble(String cip) {
    store.removeBubble(cip);
    // Signals store is the sole source of truth for UI state
    // No persistence needed for individual bubble removal
  }

  void clearAllBubbles() {
    store.clearAllBubbles();
    // Signals store is the sole source of truth for UI state
    // No persistence needed for bubble history
  }

  void setMode(ScannerMode mode) {
    // ScannerStore is the sole source of truth for UI state
    store.setMode(mode);
    // Note: We don't sync mode to Riverpod since it's high-frequency UI state
    // ScannerNotifier remains focused on business logic only
  }

  // Computed properties for easy access (typed)
  final Computed<int> bubbleCount = store.bubbleCount;
  final Computed<bool> hasBubbles = store.hasBubbles;
  final Signal<List<ScanResult>> bubbles = store.bubbles;
  final Signal<ScannerMode> mode = store.mode;
  final Computed<bool> isAtCapacity = store.isAtCapacity;
  final Computed<bool> hasDuplicateScans = store.hasDuplicateScans;

  return ScannerLogic(
    store: store,
    handleScanResult: handleScanResult,
    removeBubble: removeBubble,
    clearAllBubbles: clearAllBubbles,
    setMode: setMode,
    // Computed signals for direct access
    bubbleCount: bubbleCount,
    hasBubbles: hasBubbles,
    bubbles: bubbles,
    mode: mode,
    isAtCapacity: isAtCapacity,
    hasDuplicateScans: hasDuplicateScans,
  );
}

/// Controller class that bridges ScannerStore with Flutter widgets
///
/// This class provides the public API for interacting with scanner logic
/// while keeping the Signals store encapsulated for optimal performance.
class ScannerLogic {
  final ScannerStore store;
  final void Function(ScanResult) handleScanResult;
  final void Function(String) removeBubble;
  final void Function() clearAllBubbles;
  final void Function(ScannerMode) setMode;

  // Computed signals for direct widget access
  final Computed<int> bubbleCount; // FlutterComputed<int>
  final Computed<bool> hasBubbles; // FlutterComputed<bool>
  final Signal<List<ScanResult>> bubbles; // FlutterSignal<List<ScanResult>>
  final Signal<ScannerMode> mode; // FlutterSignal<ScannerMode>
  final Computed<bool> isAtCapacity; // FlutterComputed<bool>
  final Computed<bool> hasDuplicateScans; // FlutterComputed<bool>

  const ScannerLogic({
    required this.store,
    required this.handleScanResult,
    required this.removeBubble,
    required this.clearAllBubbles,
    required this.setMode,
    required this.bubbleCount,
    required this.hasBubbles,
    required this.bubbles,
    required this.mode,
    required this.isAtCapacity,
    required this.hasDuplicateScans,
  });

  /// Check if a specific code is in cooldown
  bool isInCooldown(String codeCip) {
    return store.scannedCodes.value.contains(codeCip);
  }

  /// Get debug snapshot for development
  ScannerStateSnapshot get debugSnapshot => store.snapshot;
}
