import 'dart:async';

import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'initialization_provider.g.dart';

enum InitializationState { initializing, success, error }

@riverpod
class InitializationStateNotifier extends _$InitializationStateNotifier {
  String? _lastErrorMessage;
  Future<void>? _ongoingInitialization;

  String? get lastErrorMessage => _lastErrorMessage;

  @override
  InitializationState build() {
    unawaited(_checkExistingDatabase());
    return InitializationState.initializing;
  }

  Future<void> _checkExistingDatabase() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final hasData = await db.catalogDao.hasExistingData();
      final version = await db.settingsDao.getBdpmVersion();
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

      if (ref.mounted) {
        await initialize();
      }
    } on Exception catch (e) {
      LoggerService.info(
        '[InitializationProvider] Check failed, proceeding with init: $e',
      );
      if (ref.mounted) {
        await initialize();
      }
    }
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

@riverpod
String? initializationErrorMessage(Ref ref) {
  ref.watch(initializationStateProvider);
  return ref.watch(initializationStateProvider.notifier).lastErrorMessage;
}

@riverpod
Stream<InitializationStep> initializationStep(Ref ref) async* {
  final service = ref.watch(dataInitializationServiceProvider);
  final initState = ref.watch(initializationStateProvider);

  try {
    final db = ref.read(appDatabaseProvider);
    final hasData = await db.catalogDao.hasExistingData();
    final version = await db.settingsDao.getBdpmVersion();
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

@riverpod
Stream<String> initializationDetail(Ref ref) {
  final service = ref.watch(dataInitializationServiceProvider);
  return service.onDetailChanged;
}
