import 'dart:async';

import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'initialization_provider.g.dart';

enum InitializationState { initializing, success, error }

@Riverpod(keepAlive: true)
class InitializationStateNotifier extends _$InitializationStateNotifier {
  String? _lastErrorMessage;
  Future<void>? _ongoingInitialization;

  String? get lastErrorMessage => _lastErrorMessage;

  @override
  InitializationState build() {
    return InitializationState.initializing;
  }

  Future<void> initialize() {
    _ongoingInitialization ??= _runInitialization().whenComplete(() {
      _ongoingInitialization = null;
    });
    return _ongoingInitialization!;
  }

  Future<void> _runInitialization() async {
    if (!ref.mounted || state == InitializationState.success) {
      return;
    }

    state = InitializationState.initializing;
    _lastErrorMessage = null;
    try {
      final db = ref.read(databaseProvider);
      final hasData = await db.catalogDao.hasExistingData();
      final prefs = ref.read(preferencesServiceProvider);
      final version = prefs.getBdpmVersion();
      const currentVersion = DataInitializationService.dataVersion;

      if (hasData && version == currentVersion) {
        LoggerService.info(
          '[InitializationProvider] Database already initialized',
        );
        if (ref.mounted) {
          state = InitializationState.success;
        }
        return;
      }

      LoggerService.info('[InitializationProvider] initialize() - start');
      await ref.read(dataInitializationServiceProvider).initializeDatabase();
      if (ref.mounted) {
        state = InitializationState.success;
        LoggerService.info('[InitializationProvider] initialize() - success');
      }
    } on Exception catch (e, stackTrace) {
      if (ref.mounted) {
        _lastErrorMessage = e.toString();
        LoggerService.error(
          '[InitializationProvider] initialize() - error',
          e,
          stackTrace,
        );
        state = InitializationState.error;
      }
    }
  }

  void setError() {
    state = InitializationState.error;
  }
}

@Riverpod(keepAlive: true)
String? initializationErrorMessage(Ref ref) {
  ref.watch(initializationStateProvider);
  return ref.watch(initializationStateProvider.notifier).lastErrorMessage;
}

@Riverpod(keepAlive: true)
Stream<InitializationStep> initializationStep(Ref ref) async* {
  final service = ref.watch(dataInitializationServiceProvider);
  final initState = ref.watch(initializationStateProvider);
  LoggerService.info(
    '[InitializationStepProvider] listening (state: $initState)',
  );

  try {
    final db = ref.read(databaseProvider);
    final prefs = ref.read(preferencesServiceProvider);
    final hasData = await db.catalogDao.hasExistingData();
    final version = prefs.getBdpmVersion();
    const currentVersion = DataInitializationService.dataVersion;

    if (hasData && version == currentVersion) {
      yield InitializationStep.ready;
      yield* service.onStepChanged;
      return;
    }
  } on Exception catch (e) {
    LoggerService.info(
      '[InitializationStepProvider] Database check failed, using stream: $e',
    );
  }

  if (initState == InitializationState.success) {
    yield InitializationStep.ready;
    yield* service.onStepChanged;
    return;
  }

  yield InitializationStep.idle;

  await for (final step in service.onStepChanged) {
    yield step;
    final currentInitState = ref.read(initializationStateProvider);
    if (currentInitState == InitializationState.success &&
        step != InitializationStep.ready) {
      LoggerService.info(
        '[InitializationStepProvider] forcing ready after init success',
      );
      yield InitializationStep.ready;
    }
    if (step == InitializationStep.ready) {
      yield* service.onStepChanged;
      return;
    }
  }

  final finalInitState = ref.read(initializationStateProvider);
  if (finalInitState == InitializationState.success) {
    yield InitializationStep.ready;
  }
}

@Riverpod(keepAlive: true)
Stream<String> initializationDetail(Ref ref) {
  final service = ref.watch(dataInitializationServiceProvider);
  return service.onDetailChanged;
}
