import 'dart:async';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/models/scan_models.dart';
import 'package:pharma_scan/features/scanner/domain/scanner_mode.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// High-performance scanner logic store using Dart Signals.
/// Handles complex local state that changes frequently without causing widget rebuilds.
class ScannerStore {
  ScannerStore() {
    // Initialize side effects on creation
    _setupCooldownCleanup();
  }

  // CONSTANTS
  static const int _maxBubbles = AppConfig.scannerHistoryLimit;
  static const Duration _bubbleLifetime = AppConfig.scannerBubbleLifetime;
  static const Duration _codeCleanupDelay = AppConfig.scannerCodeCleanupDelay;

  // TIMERS STATE
  final Map<String, Timer> _dismissTimers = {};
  Timer? _cleanupTimer;
  String? _pendingCleanupCode;

  // 1. CORE SIGNALS (State)
  final bubbles = signal<List<ScanResult>>([]);
  final scannedCodes = signal<Set<String>>({}); // Set for O(1) lookups
  final mode = signal<ScannerMode>(ScannerMode.analysis);

  // 2. COMPUTED SIGNALS (Derived State - TypeScript magic!)
  // These automatically update when dependencies change, no manual dependency arrays needed
  late final bubbleCount = computed(() => bubbles.value.length);
  late final hasBubbles = computed(() => bubbles.value.isNotEmpty);
  late final isEmpty = computed(() => bubbles.value.isEmpty);
  late final isAtCapacity = computed(() => bubbles.value.length >= _maxBubbles);

  // Performance optimizations
  late final firstBubble =
      computed(() => bubbles.value.isNotEmpty ? bubbles.value.first : null);
  late final lastBubble =
      computed(() => bubbles.value.isNotEmpty ? bubbles.value.last : null);

  // Duplication detection
  late final hasDuplicateScans = computed(() {
    final cips = bubbles.value.map((b) => b.cip.toString()).toList();
    return cips.length != cips.toSet().length;
  });

  // 3. ACTIONS (Methods that modify signals)

  /// Adds a new scan result to the bubble stack
  void addScan(ScanResult result) {
    if (_isInCooldown(result.cip.toString())) {
      return; // Skip if already in cooldown
    }

    final codeCip = result.cip.toString();

    // Remove existing bubble if present
    _removeExistingBubble(codeCip);

    // Add to scanned codes set for fast lookup
    scannedCodes.value = {...scannedCodes.value, codeCip};

    // Manage bubble capacity (remove oldest if at limit)
    _manageCapacity();

    // Add new bubble at the beginning
    bubbles.value = [result, ...bubbles.value];

    // Setup auto-dismiss timer
    _setupBubbleTimer(codeCip);
  }

  /// Removes a bubble by its CIP code
  void removeBubble(String codeCip) {
    final index = bubbles.value.indexWhere((b) => b.cip.toString() == codeCip);
    if (index == -1) return;

    final newBubbles = List<ScanResult>.from(bubbles.value);
    newBubbles.removeAt(index);
    bubbles.value = newBubbles;
    _cleanupBubbleTimer(codeCip);

    // Delayed cleanup of scanned codes to prevent immediate re-scan
    _scheduleCodeCleanup(codeCip);
  }

  /// Clears all bubbles and resets state
  void clearAllBubbles() {
    bubbles.value = [];
    scannedCodes.value = {};
    _cleanupAllTimers();
  }

  /// Updates scanner mode
  void setMode(ScannerMode newMode) {
    mode.value = newMode;
  }

  // 4. PRIVATE HELPER METHODS

  bool _isInCooldown(String codeCip) {
    return _dismissTimers.containsKey(codeCip) ||
        scannedCodes.value.contains(codeCip);
  }

  void _removeExistingBubble(String codeCip) {
    final existingIndex =
        bubbles.value.indexWhere((b) => b.cip.toString() == codeCip);
    if (existingIndex != -1) {
      final newBubbles = List<ScanResult>.from(bubbles.value);
      newBubbles.removeAt(existingIndex);
      bubbles.value = newBubbles;
      _cleanupBubbleTimer(codeCip);
    }
  }

  void _manageCapacity() {
    if (bubbles.value.length >= _maxBubbles) {
      final currentBubbles = List<ScanResult>.from(bubbles.value);
      final oldest = currentBubbles.removeLast();
      final oldestCode = oldest.cip.toString();
      bubbles.value = currentBubbles;
      _cleanupBubbleTimer(oldestCode);
      scannedCodes.value = Set<String>.from(scannedCodes.value)
        ..remove(oldestCode);
    }
  }

  void _setupBubbleTimer(String codeCip) {
    _cleanupBubbleTimer(codeCip); // Cancel existing timer if any

    final timer = Timer(_bubbleLifetime, () => removeBubble(codeCip));
    _dismissTimers[codeCip] = timer;
  }

  void _cleanupBubbleTimer(String codeCip) {
    _dismissTimers[codeCip]?.cancel();
    _dismissTimers.remove(codeCip);
  }

  void _scheduleCodeCleanup(String codeCip) {
    _cleanupTimer?.cancel();
    _pendingCleanupCode = codeCip;

    _cleanupTimer = Timer(_codeCleanupDelay, () {
      if (_pendingCleanupCode == codeCip) {
        scannedCodes.value = Set<String>.from(scannedCodes.value)
          ..remove(codeCip);
        _pendingCleanupCode = null;
      }
    });
  }

  void _cleanupAllTimers() {
    for (final timer in _dismissTimers.values) {
      timer.cancel();
    }
    _dismissTimers.clear();
    _cleanupTimer?.cancel();
    _pendingCleanupCode = null;
  }

  void _setupCooldownCleanup() {
    // This method can be used for any cleanup needed when the store is disposed
  }

  /// Cleanup method to be called when the store is no longer needed
  void dispose() {
    _cleanupAllTimers();
  }

  // 5. DEBUG HELPERS

  /// Returns current state snapshot for debugging
  ScannerStateSnapshot get snapshot => ScannerStateSnapshot(
        bubbleCount: bubbleCount.value,
        hasBubbles: hasBubbles.value,
        hasDuplicateScans: hasDuplicateScans.value,
        isAtCapacity: isAtCapacity.value,
        scannedCodesCount: scannedCodes.value.length,
        mode: mode.value,
      );
}

/// Debug snapshot of scanner state
class ScannerStateSnapshot {
  const ScannerStateSnapshot({
    required this.bubbleCount,
    required this.hasBubbles,
    required this.hasDuplicateScans,
    required this.isAtCapacity,
    required this.scannedCodesCount,
    required this.mode,
  });

  final int bubbleCount;
  final bool hasBubbles;
  final bool hasDuplicateScans;
  final bool isAtCapacity;
  final int scannedCodesCount;
  final ScannerMode mode;

  @override
  String toString() {
    return 'ScannerStateSnapshot('
        'bubbleCount: $bubbleCount, '
        'hasBubbles: $hasBubbles, '
        'hasDuplicateScans: $hasDuplicateScans, '
        'isAtCapacity: $isAtCapacity, '
        'scannedCodesCount: $scannedCodesCount, '
        'mode: $mode)';
  }
}
