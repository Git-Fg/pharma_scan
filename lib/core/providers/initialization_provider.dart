import 'dart:async';

import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/mixins/safe_async_notifier_mixin.dart';
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
class InitializationNotifier extends _$InitializationNotifier
    with SafeAsyncNotifierMixin {
  @override
  FutureOr<void> build() async {
    ref.onDispose(() {
      // Cleanup if needed
    });

    final result = await safeExecute(_runInitialization);

    if (!isMounted()) return;

    if (result.hasError) {
      logError(
        '[InitializationProvider] Failed to initialize database',
        result.error!,
        result.stackTrace ?? StackTrace.current,
      );
    }
  }

  Future<void> _runInitialization() async {
    ref
        .read(loggerProvider)
        .info('[InitializationProvider] initialize() - start');
    await ref.read(dataInitializationServiceProvider).initializeDatabase();

    if (!isMounted()) return;

    ref
        .read(loggerProvider)
        .info('[InitializationProvider] initialize() - success');
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
  ref
      .read(loggerProvider)
      .info('[InitializationStepProvider] listening (state: $initState)');

  try {
    final db = ref.read(databaseProvider());
    final appSettings = ref.read(appSettingsDaoProvider);
    final hasData = await db.catalogDao.hasExistingData();
    final version = await appSettings.bdpmVersion;
    // const currentVersion = DataInitializationService.dataVersion; // Removed

    // If we have data and *any* version tag, we consider it ready.
    // The DataInitializationService.initializeDatabase will verify integrity if needed.
    if (hasData && version != null && version.isNotEmpty) {
      yield InitializationStep.ready;
      yield* service.onStepChanged;
      return;
    }
  } on Exception catch (e) {
    ref.read(loggerProvider).info(
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
      ref.read(loggerProvider).info(
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
