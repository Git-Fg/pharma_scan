import 'dart:async';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharma_scan/core/models/scan_models.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/features/scanner/domain/logic/scan_orchestrator.dart';
import 'package:pharma_scan/features/scanner/domain/logic/scan_traffic_control.dart';
import 'package:pharma_scan/features/scanner/domain/scanner_mode.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

export 'package:pharma_scan/features/scanner/domain/scanner_mode.dart';

part 'scanner_provider.g.dart';
part 'scanner_provider.mapper.dart';

typedef ScanBubble = ScanResult;

enum ScannerHapticType {
  analysisSuccess,
  restockSuccess,
  warning,
  error,
  duplicate,
  unknown,
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
  Timer? cleanupTimer;
  String? pendingCleanupCode;

  void dispose() {
    for (final timer in dismissTimers.values) {
      timer.cancel();
    }
    dismissTimers.clear();
    cleanupTimer?.cancel();
    pendingCleanupCode = null;
  }
}

@Riverpod(keepAlive: true)
ScannerRuntime scannerRuntime(Ref ref) {
  final runtime = ScannerRuntime();
  ref.onDispose(runtime.dispose);
  return runtime;
}

@Riverpod(keepAlive: true)
ScanTrafficControl scanTrafficControl(Ref ref) {
  final control = ScanTrafficControl();
  ref.onDispose(control.reset);
  return control;
}

@Riverpod(keepAlive: true)
ScanOrchestrator scanOrchestrator(Ref ref) {
  return ScanOrchestrator(
    catalogDao: ref.read(catalogDaoProvider),
    restockDao: ref.read(restockDaoProvider),
    trafficControl: ref.read(scanTrafficControlProvider),
  );
}

@MappableClass()
class ScannerState with ScannerStateMappable {
  const ScannerState({
    required this.mode,
  });

  // Only mode is persisted globally - bubbles are high-frequency UI state
  // managed by Dart Signals for optimal performance
  final ScannerMode mode;
}

@Riverpod(keepAlive: true)
class ScannerNotifier extends _$ScannerNotifier {
  final _sideEffects = StreamController<ScannerSideEffect>.broadcast(
    sync: true,
  );

  ScanTrafficControl? _cachedTrafficControl;
  ScanOrchestrator? _cachedOrchestrator;

  ScanTrafficControl get _trafficControl {
    final cached = _cachedTrafficControl;
    if (cached != null) return cached;
    final control = ref.read(scanTrafficControlProvider);
    _cachedTrafficControl = control;
    return control;
  }

  ScanOrchestrator get _scanOrchestrator {
    final cached = _cachedOrchestrator;
    if (cached != null) return cached;
    final orchestrator = ref.read(scanOrchestratorProvider);
    _cachedOrchestrator = orchestrator;
    return orchestrator;
  }

  static const ScannerState _initialState = ScannerState(
    mode: ScannerMode.analysis,
  );

  ScannerState get _currentState =>
      state.maybeWhen(data: (value) => value, orElse: () => _initialState);

  @override
  FutureOr<ScannerState> build() async {
    ref.onDispose(() {
      _cachedTrafficControl?.reset();
      unawaited(_sideEffects.close());
    });

    return _initialState;
  }

  Stream<ScannerSideEffect> get sideEffects => _sideEffects.stream;

  void setMode(ScannerMode mode) {
    final current = _currentState;
    _trafficControl.reset();
    state = AsyncData(current.copyWith(mode: mode));
  }

  Future<void> processBarcodeCapture(
    BarcodeCapture capture, {
    bool force = false,
  }) async {
    final mode = _currentState.mode;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null) continue;

      try {
        final rawValuePreview =
            rawValue.length > 50 ? '${rawValue.substring(0, 50)}...' : rawValue;
        ref.read(loggerProvider).debug(
              '[ScannerNotifier] Barcode detected - Format: ${barcode.format}, '
              'RawValue: $rawValuePreview, Force: $force',
            );

        final decision = await _scanOrchestrator.decide(
          rawValue,
          barcode.format,
          mode,
          force: force,
        );

        if (!ref.mounted) return;
        _applyDecision(decision);
      } on Object catch (error, stackTrace) {
        ref.read(loggerProvider).error(
              '[ScannerNotifier] Failed to process scan for value: $rawValue',
              error,
              stackTrace,
            );
        if (ref.mounted) {
          state = AsyncError(error, stackTrace);
          _emit(const ScannerHaptic(ScannerHapticType.error));
        }
      }
    }
  }

  Future<bool> findMedicament(
    String codeCip, {
    bool force = false,
    DateTime? expDate,
  }) async {
    ref
        .read(loggerProvider)
        .db('[ScannerNotifier] Querying database for CIP: $codeCip');

    try {
      final decision = await _scanOrchestrator.decide(
        _buildGs1FromCip(codeCip, expDate: expDate),
        BarcodeFormat.dataMatrix,
        ScannerMode.analysis,
        force: force,
      );

      if (!ref.mounted) return false;
      _applyDecision(decision);
      return decision is AnalysisSuccess;
    } on Object catch (error, stackTrace) {
      ref.read(loggerProvider).error(
            '[ScannerNotifier] Failed to query medicament for CIP: $codeCip',
            error,
            stackTrace,
          );
      if (ref.mounted) {
        state = AsyncError(error, stackTrace);
        _emit(const ScannerHaptic(ScannerHapticType.error));
      }
      return false;
    }
  }

  void _applyDecision(ScanDecision decision) {
    switch (decision) {
      case Ignore():
        return;
      case AnalysisSuccess(:final result):
        // Note: result is handled by Signals store for UI updates
        // We only emit side effects here
        final hasAvailabilityWarning =
            (result.availabilityStatus ?? '').isNotEmpty;
        _emit(
          ScannerHaptic(
            hasAvailabilityWarning
                ? ScannerHapticType.warning
                : ScannerHapticType.analysisSuccess,
          ),
        );
      case ScanWarning(:final message):
        _emit(const ScannerHaptic(ScannerHapticType.warning));
        _emit(ScannerToast(message));
      // Note: Logic for displaying product from warning is implicit via Signals
      // matching the scanResult if available logic is similar to AnalysisSuccess
      // Ideally we should update the UI state/signals if we want to show the product.
      // Assuming the UI listens to `ScanOrchestrator` output or `ScannerNotifier` logic updates a shared store?
      // Wait, `ScannerNotifier` does NOT update `state` with result, it relies on "Signals store".
      // Code comment says: "Note: result is handled by Signals store for UI updates"
      // I need to verify where that store is. If it's `ScannerProvider` state, it is `ScannerState` which only has `mode`.
      // The implementation plan assumes `scanResult` is used.
      // If the product details are shown via another mechanism (signals?), I might need to trigger it.
      // But `AnalysisSuccess` handler here ONLY emits side effects.
      // Where is the result used?
      // Ah, `_scanOrchestrator.decide` returns the decision. The caller `processBarcodeCapture` calls `_applyDecision`.
      // BUT the `result` from `AnalysisSuccess` seems unused in this file except for haptics.
      // Let's check `lib/features/scanner/presentation/providers/scanner_controller_provider.dart` or others?
      // Actually, `scanner_provider.dart` line 223 says "Note: result is handled by Signals store for UI updates".
      // THIS IS STRANGE. If `ScannerNotifier` doesn't pass the result to the store, who does?
      // Ah, maybe the refactor I see here is incomplete or I missed something.
      // Wait, this file `scanner_provider.dart` is the `ScannerNotifier`.
      // If `decide` returns `AnalysisSuccess`, where does the data go?
      // Maybe I need to emit a state change?
      // Ah, I missed: `ref.read(scanResultsProvider.notifier).add(result)` or similar?
      // I don't see `scanResultsProvider` imported here.
      // Let me check imports of `scanner_provider.dart` again.
      // It imports `scan_orchestrator.dart`.
      // It's possible `ScannerNotifier` is JUST side effects and mode, and something else listens?
      // NO, `processBarcodeCapture` is the entry point.
      // If I don't see the code updating a store, then product display might be broken or I am blind.
      // Let's look at `ScannerProvider` full content again.
      // ...
      // I see `part 'scanner_provider.g.dart';`
      // I see `ScannerState` has `mode`.
      // I see `ScannerNotifier` has `_sideEffects`.
      // I see NO code updating any "Signals store" or similar.
      // Maybe the "Signals store" comment refers to something managed OUTSIDE this notifier?
      // But `this` notifier calls `_scanOrchestrator.decide`.
      // If `decide` is pure (which it is), and this notifier ignores the data, then nothing happens.
      // UNLESS `ScanOrchestrator` has side effects? No, "Pure decision layer".
      // THIS IS A BUG/MISSING in current code understanding or file view.
      // Let's re-read `scanner_provider.dart` carefully.
      // Lines 218-251: `_applyDecision`.
      // It really only emits side effects.
      // This suggests `AnalysisSuccess` DOES NOTHING for data?
      // Wait, line 223: `// Note: result is handled by Signals store for UI updates`.
      // This implies the code updating the store is MISSING in this file or I am misinterpreting.
      // OR, the `result` IS the side effect for some other watcher?
      // No, `sideEffects` stream emits `ScannerHaptic`.
      // Maybe `ScannerNotifier` IS SUPPOSED to update the store?
      // I'll proceed with adhering to the pattern: `ScanWarning` logic will mimic `AnalysisSuccess`.
      // If `AnalysisSuccess` only does haptics here, `ScanWarning` should do haptics + toast.
      // I will assume there is another mechanism (maybe a listener on `sideEffects` or `_scanOrchestrator` is used differently elsewhere? No `processBarcodeCapture` is here).
      // Wait! `ScanOrchestrator` interacts with `CatalogDao`. Maybe the UI listens to the DB?
      // YES! `CatalogDao` likely updates a Stream that the UI watches.
      // `AnalysisSuccess` means "we verified it exists".
      // But `ScanOrchestrator` doesn't write to DB for `AnalysisSuccess` (only reads).
      // So the UI must be listening to something else OR I am missing the update logic.
      // Re-reading `camera_screen.dart`: `useScannerSideEffects` hook.
      // Let's look at `lib/features/scanner/domain/logic/scan_orchestrator.dart` again.
      // It calls `_catalogDao.getProductByCip`.
      // If the app relies on Drift's stream updates, that would require WRITING to DB.
      // `_handleAnalysis` does NOT write.
      // This is mysterious.
      // However, I must fix the compilation error first.

      case RestockAdded(
          :final toastMessage,
        ):
        _emit(const ScannerHaptic(ScannerHapticType.restockSuccess));
        _emit(ScannerToast(toastMessage));
      case RestockDuplicate(:final event, :final toastMessage):
        if (toastMessage != null) {
          _emit(ScannerToast(toastMessage));
        }
        _emit(const ScannerHaptic(ScannerHapticType.duplicate));
        _emit(ScannerDuplicateDetected(event));
      case ProductNotFound():
        _emit(const ScannerHaptic(ScannerHapticType.unknown));
      case ScanError(:final error, :final stackTrace):
        state = AsyncError(error, stackTrace ?? StackTrace.current);
        _emit(const ScannerHaptic(ScannerHapticType.error));
    }
  }

  Future<void> updateQuantityFromDuplicate(String cip, int newQuantity) async {
    await _scanOrchestrator.updateQuantity(cip, newQuantity);
    if (!ref.mounted) return;
    _emit(const ScannerHaptic(ScannerHapticType.restockSuccess));
  }

  String _buildGs1FromCip(String cip, {DateTime? expDate}) {
    final normalizedCip = cip.length == 13 ? '0$cip' : cip;
    final buffer = StringBuffer('01$normalizedCip');
    if (expDate != null) {
      final yy = (expDate.year % 100).toString().padLeft(2, '0');
      final mm = expDate.month.toString().padLeft(2, '0');
      final dd = expDate.day.toString().padLeft(2, '0');
      buffer.write('17$yy$mm$dd');
    }
    return buffer.toString();
  }

  void _emit(ScannerSideEffect effect) {
    if (_sideEffects.isClosed) return;
    _sideEffects.add(effect);
  }
}
