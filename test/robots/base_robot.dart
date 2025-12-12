import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Base class for Robot pattern implementations.
///
/// Provides common utilities for widget test interactions.
/// Robots encapsulate finders and actions to keep tests clean and maintainable.
abstract class BaseRobot {
  BaseRobot(this.tester);

  final WidgetTester tester;

  /// Waits until a finder is visible, with optional timeout.
  ///
  /// Useful for async state that may take time to appear.
  Future<void> waitUntilVisible(
    Finder finder, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final endTime = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(endTime)) {
      await tester.pump();
      if (finder.evaluate().isNotEmpty) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw TimeoutException(
      'Finder did not become visible within ${timeout.inSeconds} seconds',
      timeout,
    );
  }

  /// Pumps and settles, ensuring all animations complete.
  Future<void> pumpAndSettle() async {
    await tester.pumpAndSettle();
  }

  /// Pumps with a specific duration (useful for debounce testing).
  Future<void> pump(Duration duration) async {
    await tester.pump(duration);
  }
}
