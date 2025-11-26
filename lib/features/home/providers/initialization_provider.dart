// lib/features/home/providers/initialization_provider.dart
import 'dart:async';

import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

part 'initialization_provider.g.dart';

enum InitializationState { initializing, success, error }

@riverpod
class InitializationStateNotifier extends _$InitializationStateNotifier {
  String? _lastErrorMessage;
  Future<void>? _ongoingInitialization;

  String? get lastErrorMessage => _lastErrorMessage;

  @override
  InitializationState build() {
    // WHY: Check database state immediately on build
    // If no data exists, return initializing state to block app access
    _checkExistingDatabase();
    // WHY: Start with initializing state - will update to success if data exists
    return InitializationState.initializing;
  }

  Future<void> _checkExistingDatabase() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final hasData = await db.libraryDao.hasExistingData();
      final version = await db.settingsDao.getBdpmVersion();
      // WHY: Use the same version check as DataInitializationService
      // If database exists and version matches, we can mark as success
      const currentVersion = DataInitializationService.dataVersion;

      if (hasData && version == currentVersion) {
        // WHY: Database exists and is up-to-date - mark as success
        LoggerService.info(
          '[InitializationProvider] Database already initialized',
        );
        state = InitializationState.success;
        return;
      }

      // WHY: If database doesn't exist or version doesn't match, start initialization
      await initialize();
    } catch (e) {
      // WHY: If check fails, proceed with normal initialization
      LoggerService.info(
        '[InitializationProvider] Check failed, proceeding with init: $e',
      );
      await initialize();
    }
  }

  Future<void> initialize() {
    _ongoingInitialization ??= _runInitialization().whenComplete(() {
      _ongoingInitialization = null;
    });
    return _ongoingInitialization!;
  }

  Future<void> _runInitialization() async {
    // WHY: If already successful, skip initialization
    if (state == InitializationState.success) {
      return;
    }

    state = InitializationState.initializing;
    _lastErrorMessage = null;
    try {
      LoggerService.info('[InitializationProvider] initialize() - start');
      await ref.read(dataInitializationServiceProvider).initializeDatabase();
      state = InitializationState.success;
      LoggerService.info('[InitializationProvider] initialize() - success');
    } catch (e, stackTrace) {
      _lastErrorMessage = e.toString();
      LoggerService.error(
        '[InitializationProvider] initialize() - error',
        e,
        stackTrace,
      );
      state = InitializationState.error;
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
  
  // WHY: Check if database is already initialized before listening to stream
  // This prevents infinite loading when database exists but service hasn't emitted ready
  try {
    final db = ref.read(appDatabaseProvider);
    final hasData = await db.libraryDao.hasExistingData();
    final version = await db.settingsDao.getBdpmVersion();
    const currentVersion = DataInitializationService.dataVersion;
    
    if (hasData && version == currentVersion) {
      // WHY: Database is already initialized - emit ready immediately
      yield InitializationStep.ready;
      // WHY: Continue listening to stream for future updates
      yield* service.onStepChanged;
      return;
    }
  } catch (e) {
    // WHY: If check fails, proceed with normal stream flow
    LoggerService.info(
      '[InitializationStepProvider] Database check failed, using stream: $e',
    );
  }
  
  // WHY: If initialization state is already success, emit ready immediately
  // This handles the case where initialization completes but service stream hasn't emitted ready
  if (initState == InitializationState.success) {
    yield InitializationStep.ready;
    // WHY: Continue listening to stream for future updates
    yield* service.onStepChanged;
    return;
  }
  
  // WHY: Start with idle state, then emit from stream
  // This ensures we have an initial value before the stream emits
  yield InitializationStep.idle;
  
  // WHY: Listen to service stream and also watch initialization state
  // If initialization state becomes success, emit ready even if service doesn't
  await for (final step in service.onStepChanged) {
    yield step;
    // WHY: Check initialization state after each step
    // If it becomes success, we can emit ready
    final currentInitState = ref.read(initializationStateProvider);
    if (currentInitState == InitializationState.success &&
        step != InitializationStep.ready) {
      yield InitializationStep.ready;
    }
    // WHY: If service emits ready, we're done with this iteration
    if (step == InitializationStep.ready) {
      // Continue listening for future updates
      yield* service.onStepChanged;
      return;
    }
  }
  
  // WHY: If service stream ends without emitting ready, check initialization state as fallback
  final finalInitState = ref.read(initializationStateProvider);
  if (finalInitState == InitializationState.success) {
    yield InitializationStep.ready;
  }
}
