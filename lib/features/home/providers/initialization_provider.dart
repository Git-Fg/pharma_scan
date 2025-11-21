// lib/features/home/providers/initialization_provider.dart
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

part 'initialization_provider.g.dart';

enum InitializationState { initializing, success, error }

@riverpod
class InitializationStateNotifier extends _$InitializationStateNotifier {
  String? _lastErrorMessage;

  String? get lastErrorMessage => _lastErrorMessage;

  @override
  InitializationState build() => InitializationState.initializing;

  Future<void> initialize() async {
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
