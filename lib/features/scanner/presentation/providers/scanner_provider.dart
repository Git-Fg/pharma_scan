import 'dart:async';
import 'dart:io';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/models/scan_result.dart';
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
    restockDao: ref.read(databaseProvider).restockDao,
    trafficControl: ref.read(scanTrafficControlProvider),
  );
}

@MappableClass()
class ScannerState with ScannerStateMappable {
  const ScannerState({
    required this.bubbles,
    required this.scannedCodes,
    required this.mode,
    this.isLowEndDevice = false,
  });

  final List<ScanBubble> bubbles;
  final Set<String> scannedCodes;
  final ScannerMode mode;
  @MappableField(key: 'isLowEndDevice')
  final bool isLowEndDevice;
}

@Riverpod(keepAlive: true)
class ScannerNotifier extends _$ScannerNotifier {
  static const int _maxBubbles = AppConfig.scannerHistoryLimit;
  static const Duration _bubbleLifetime = AppConfig.scannerBubbleLifetime;
  static const Duration _codeCleanupDelay = AppConfig.scannerCodeCleanupDelay;
  static const Duration _codeRemovalDelay = Duration(seconds: 3);

  final _sideEffects = StreamController<ScannerSideEffect>.broadcast(
    sync: true,
  );

  ScannerRuntime? _cachedRuntime;
  ScanTrafficControl? _cachedTrafficControl;
  ScanOrchestrator? _cachedOrchestrator;

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  ScannerRuntime get _runtime {
    final runtime = _cachedRuntime;
    if (runtime != null) return runtime;
    final created = ref.read(scannerRuntimeProvider);
    _cachedRuntime = created;
    return created;
  }

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
    bubbles: [],
    scannedCodes: {},
    mode: ScannerMode.analysis,
  );

  ScannerState get _currentState =>
      state.maybeWhen(data: (value) => value, orElse: () => _initialState);

  @override
  FutureOr<ScannerState> build() async {
    ref.onDispose(() {
      final runtime = _cachedRuntime;
      runtime?.dispose();
      _cachedTrafficControl?.reset();
      unawaited(_sideEffects.close());
    });

    final isLowEnd = await _checkDeviceCapabilities();

    return _initialState.copyWith(isLowEndDevice: isLowEnd);
  }

  Future<bool> _checkDeviceCapabilities() async {
    try {
      // Pour le web, on considère que les capacités sont suffisantes
      if (kIsWeb) {
        return false;
      }

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        // Simple heuristic: Android 8.0 (SDK 26) or lower might be considered "low end"
        // for heavy ML tasks, or check memory if available (not directly in basic info).
        // Here we just check SDK version as an example.
        return androidInfo.version.sdkInt <= 26;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        // Example: iPhone 6s or older (just a placeholder logic)
        return !iosInfo
            .isPhysicalDevice; // Treat simulator as low end for testing or similar
      }
    } catch (e) {
      LoggerService.error('Failed to check device capabilities', e);
    }
    return false;
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
        final rawValuePreview = rawValue.length > 50
            ? '${rawValue.substring(0, 50)}...'
            : rawValue;
        LoggerService.debug(
          '[ScannerNotifier] Barcode detected - Format: ${barcode.format}, '
          'RawValue: $rawValuePreview, Force: $force',
        );

        final decision = await _scanOrchestrator.decide(
          rawValue,
          mode,
          force: force,
          scannedCodes: _currentState.scannedCodes,
          existingBubbles: _currentState.bubbles,
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
        scannedCodes: _currentState.scannedCodes,
        existingBubbles: _currentState.bubbles,
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
        if (replacedExisting) {
          removeBubble(result.cip.toString());
        }
        addBubble(result);
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
        addBubble(scanResult);
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
      (bubble) => bubble.cip.toString() == codeCip,
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
    _trafficControl.reset();

    state = const AsyncData(_initialState);
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
