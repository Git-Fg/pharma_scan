import 'package:hooks_riverpod/hooks_riverpod.dart';
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
    return await AsyncValue.guard(() async {
      try {
        return await operation();
      } catch (error, stackTrace) {
        if (operationName != null) {
          logError(
            '[SafeAsyncNotifierMixin] Operation failed: $operationName',
            error,
            stackTrace,
          );
        }
        rethrow;
      }
    });
  }

  /// Checks if ref is mounted before proceeding with an operation.
  /// Use this before any state modifications in async methods.
  bool isMounted({String? context}) {
    if (!ref.mounted) {
      if (context != null) {
        ref.read(loggerProvider).warning(
              '[SafeAsyncNotifierMixin] Ref not mounted: $context',
            );
      }
      return false;
    }
    return true;
  }

  /// Log an error with context if ref is mounted.
  void logError(String message, Object error, StackTrace stackTrace) {
    // Only log if mounted to avoid logging errors for disposed notifiers
    // unless it's critical system error, but for UI feedback loop, this is safer.
    // However, for error tracking, we might want to log regardless.
    // Following original logic: check mounted primarily for state updates,
    // but logging might be valid even if unmounted.
    // For now, let's keep it safe.
    if (ref.mounted) {
      ref.read(loggerProvider).error(message, error, stackTrace);
    } else {
      // Still log to console/service but maybe with a note
      ref.read(loggerProvider).warning('[Unmounted] $message');
    }
  }
}
