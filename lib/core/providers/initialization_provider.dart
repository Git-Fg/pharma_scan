import 'dart:async';

import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'initialization_provider.g.dart';

/// Initialization states for the application
enum InitializationState {
  initial,
  initializing,
  ready,
  success,
  error;
}

@Riverpod(keepAlive: true)
class InitializationNotifier extends _$InitializationNotifier {
  @override
  FutureOr<void> build() async {
    ref.onDispose(() {});

    final result = await AsyncValue.guard(_runInitialization);

    if (!ref.mounted) return;

    if (result.hasError) {
      ref.read(loggerProvider).error(
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

    if (!ref.mounted) return;

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

    if (hasData && version != null && version.isNotEmpty) {
      yield .ready;
      yield* service.onStepChanged;
      return;
    }
  } on Exception catch (e) {
    ref.read(loggerProvider).info(
        '[InitializationStepProvider] Database check failed, using stream: $e');
  }

  if (initState.hasValue) {
    yield .ready;
    yield* service.onStepChanged;
    return;
  }

  yield .idle;

  await for (final step in service.onStepChanged) {
    yield step;
    final currentInitState = ref.read(initializationProvider);
    if (currentInitState.hasValue && step != .ready) {
      ref.read(loggerProvider).info(
          '[InitializationStepProvider] forcing ready after init success');
      yield .ready;
    }
    if (step == .ready) {
      yield* service.onStepChanged;
      return;
    }
  }

  final finalInitState = ref.read(initializationProvider);
  if (finalInitState.hasValue) {
    yield .ready;
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
    data: (_) => .ready,
    loading: () => .initializing,
    error: (_, __) => .error,
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
