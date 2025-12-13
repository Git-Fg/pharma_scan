import 'package:pharma_scan/core/models/scan_result.dart';
import 'package:pharma_scan/features/scanner/logic/scanner_store.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

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

  // Watch the existing scanner state and sync with Signals
  final scannerState = ref.watch(scannerProvider);
  final scannerNotifier = ref.read(scannerProvider.notifier);

  // Initialize store with device capabilities
  useEffect(() {
    store.setLowEndDevice(false); // TODO: Implement actual device detection
    return null;
  }, [store]);

  // Sync Signals store with Riverpod state when it changes
  useEffect(() {
    final state = scannerState.value;
    if (state != null) {
      // Sync bubbles from Riverpod to Signals
      store.bubbles.value = state.bubbles;

      // Sync mode
      store.setMode(state.mode);
    }
    return null;
  }, [scannerState.value]);

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

    // Let Riverpod handle the business logic and database operations
    // Note: This creates a temporary duplication during the transition period
    // In production, we'd modify ScannerNotifier to use the Signals store directly
  }

  void removeBubble(String cip) {
    store.removeBubble(cip);
    // Also remove from Riverpod state
    scannerNotifier.removeBubble(cip);
  }

  void clearAllBubbles() {
    store.clearAllBubbles();
    // Also clear from Riverpod state
    scannerNotifier.clearAllBubbles();
  }

  void setMode(ScannerMode mode) {
    store.setMode(mode);
    // Also set in Riverpod state
    scannerNotifier.setMode(mode);
  }

  // Computed properties for easy access
  final bubbleCount = store.bubbleCount; // FlutterComputed<int>
  final hasBubbles = store.hasBubbles; // FlutterComputed<bool>
  final bubbles = store.bubbles; // FlutterSignal<List<ScanResult>>
  final mode = store.mode; // FlutterSignal<ScannerMode>
  final isAtCapacity = store.isAtCapacity; // FlutterComputed<bool>
  final hasDuplicateScans = store.hasDuplicateScans; // FlutterComputed<bool>

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
  final dynamic bubbleCount; // FlutterComputed<int>
  final dynamic hasBubbles; // FlutterComputed<bool>
  final dynamic bubbles; // FlutterSignal<List<ScanResult>>
  final dynamic mode; // FlutterSignal<ScannerMode>
  final dynamic isAtCapacity; // FlutterComputed<bool>
  final dynamic hasDuplicateScans; // FlutterComputed<bool>

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
