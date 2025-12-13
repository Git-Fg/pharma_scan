import 'dart:async';

import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'initialization_provider.g.dart';

/// Initialization states for the application
enum InitializationState {
  initial,
  initializing,
  ready,
  success, // Alias for ready, used by tests
  error;
}

@Riverpod(keepAlive: true)
class InitializationNotifier extends _$InitializationNotifier {
  @override
  FutureOr<void> build() async {
    await _runInitialization();
  }

  Future<void> _runInitialization() async {
    final db = ref.read(databaseProvider());
    final hasData = await db.catalogDao.hasExistingData();
    final prefs = ref.read(preferencesServiceProvider);
    final version = prefs.getBdpmVersion();
    const currentVersion = DataInitializationService.dataVersion;

    if (hasData && version == currentVersion) {
      LoggerService.info(
          '[InitializationProvider] Database already initialized');
      return;
    }

    LoggerService.info('[InitializationProvider] initialize() - start');
    await ref.read(dataInitializationServiceProvider).initializeDatabase();
    LoggerService.info('[InitializationProvider] initialize() - success');
  }

  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}

@Riverpod(keepAlive: true)
Stream<InitializationStep> initializationStep(Ref ref) async* {
  final service = ref.watch(dataInitializationServiceProvider);
  final initState = ref.watch(initializationProvider);
  LoggerService.info(
      '[InitializationStepProvider] listening (state: $initState)');

  try {
    final db = ref.read(databaseProvider());
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
        '[InitializationStepProvider] Database check failed, using stream: $e');
  }

  if (initState is AsyncData<void>) {
    yield InitializationStep.ready;
    yield* service.onStepChanged;
    return;
  }

  yield InitializationStep.idle;

  await for (final step in service.onStepChanged) {
    yield step;
    final currentInitState = ref.read(initializationProvider);
    if (currentInitState is AsyncData<void> &&
        step != InitializationStep.ready) {
      LoggerService.info(
          '[InitializationStepProvider] forcing ready after init success');
      yield InitializationStep.ready;
    }
    if (step == InitializationStep.ready) {
      yield* service.onStepChanged;
      return;
    }
  }

  final finalInitState = ref.read(initializationProvider);
  if (finalInitState is AsyncData<void>) {
    yield InitializationStep.ready;
  }
}

@Riverpod(keepAlive: true)
Stream<String> initializationDetail(Ref ref) {
  final service = ref.watch(dataInitializationServiceProvider);
  return service.onDetailChanged;
}

@Riverpod(keepAlive: true)
InitializationState initializationState(Ref ref) {
  final initAsync = ref.watch(initializationProvider);
  return initAsync.when(
    data: (_) => InitializationState.ready,
    loading: () => InitializationState.initializing,
    error: (_, __) => InitializationState.error,
  );
}

@Riverpod(keepAlive: true)
String? initializationErrorMessage(Ref ref) {
  final initAsync = ref.watch(initializationProvider);
  return initAsync.when(
    data: (_) => null,
    loading: () => null,
    error: (error, _) => error.toString(),
  );
}
