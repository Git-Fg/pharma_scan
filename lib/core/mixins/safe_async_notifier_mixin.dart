import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../utils/async_notifier_helper.dart';
import '../services/logger_service.dart';

/// Lightweight mixin providing standardized ref.mounted checks and error handling
/// for notifiers. Integrates with existing LoggerService for consistency.
mixin SafeAsyncNotifierMixin {
  /// Get the ref from the implementing notifier. This must be implemented by the mixing class.
  Ref get ref;

  /// Safely executes an async operation with AsyncValue.guard pattern.
  /// Use this for write operations that need proper error handling.
  Future<AsyncValue<T>> safeExecute<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    return await AsyncNotifierHelper.safeExecute(
      operation,
      operationName: operationName,
    );
  }

  /// Checks if ref is mounted before proceeding with an operation.
  /// Use this before any state modifications in async methods.
  bool isMounted({String? context}) {
    return AsyncNotifierHelper.isMounted(ref, context: context);
  }

  /// Log an error with context if ref is mounted.
  void logError(String message, Object error, StackTrace stackTrace) {
    if (isMounted()) {
      LoggerService.error(message, error, stackTrace);
    }
  }
}