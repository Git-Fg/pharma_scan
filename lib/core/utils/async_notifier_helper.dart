import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../services/logger_service.dart';

/// Minimal utility class for standardized safe state operations in notifiers.
/// Follows the existing codebase patterns for consistency.
class AsyncNotifierHelper {
  const AsyncNotifierHelper();

  /// Safely executes an async operation with AsyncValue.guard pattern.
  /// Provides standardized error logging using LoggerService.
  static Future<AsyncValue<T>> safeExecute<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    return await AsyncValue.guard(() async {
      try {
        return await operation();
      } catch (error, stackTrace) {
        if (operationName != null) {
          LoggerService.error(
            '[AsyncNotifierHelper] Operation failed: $operationName',
            error,
            stackTrace,
          );
        }
        rethrow;
      }
    });
  }

  /// Checks if ref is mounted before proceeding with an operation.
  static bool isMounted(Ref ref, {String? context}) {
    if (!ref.mounted) {
      if (context != null) {
        LoggerService.warning(
          '[AsyncNotifierHelper] Ref not mounted: $context',
        );
      }
      return false;
    }
    return true;
  }
}