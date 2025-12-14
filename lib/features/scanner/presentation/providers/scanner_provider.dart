import 'dart:async';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharma_scan/core/models/scan_models.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
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
        LoggerService.debug(
          '[ScannerNotifier] Barcode detected - Format: ${barcode.format}, '
          'RawValue: $rawValuePreview, Force: $force',
        );

        final decision = await _scanOrchestrator.decide(
          rawValue,
          mode,
          force: force,
        );

        if (!ref.mounted) return;
        _applyDecision(decision);
      } on Object catch (error, stackTrace) {
        LoggerService.error(
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
    LoggerService.db('[ScannerNotifier] Querying database for CIP: $codeCip');

    try {
      final decision = await _scanOrchestrator.decide(
        _buildGs1FromCip(codeCip, expDate: expDate),
        ScannerMode.analysis,
        force: force,
      );

      if (!ref.mounted) return false;
      _applyDecision(decision);
      return decision is AnalysisSuccess;
    } on Object catch (error, stackTrace) {
      LoggerService.error(
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
      case AnalysisSuccess(:final result, :final replacedExisting):
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
      case RestockAdded(
          :final scanResult,
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

  /// Remove bubble (signals are the source of truth, this is for persistence only)
  void removeBubble(String cip) {
    // Signals store handles UI state - this is for any persistent cleanup if needed
    // Currently no persistent storage for individual bubbles, so this is a no-op
  }

  /// Clear all bubbles (signals are the source of truth, this is for persistence only)
  void clearAllBubbles() {
    // Signals store handles UI state - this is for any persistent cleanup if needed
    // Currently no persistent storage for bubble history, so this is a no-op
  }
}
