import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Helper to detect and track layout overflows during tests
class OverflowHelper {
  static final List<String> _overflows = [];
  static bool _isInitialized = false;

  /// Start listening for Flutter layout errors
  static void initialize() {
    if (_isInitialized) return;

    // Chain with existing error handler if present
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception is FlutterError) {
        final error = details.exception as FlutterError;
        if (error.diagnostics.any(
            (d) => d.value.toString().contains('A RenderFlex overflowed'))) {
          _overflows.add(error.toString());
        }
      }
      originalOnError?.call(details);
    };

    _isInitialized = true;
  }

  /// Verify that no overflows have occurred since initialization or last reset
  static void verifyNoOverflows() {
    if (_overflows.isNotEmpty) {
      final count = _overflows.length;
      final errors = _overflows.join('\n\n');
      _overflows.clear(); // Reset for next check
      throw Exception(
          '⚠️ Detected $count RenderFlex overflow(s) during test execution:\n$errors');
    }
  }

  /// Reset the overflow tracker
  static void reset() {
    _overflows.clear();
  }
}
