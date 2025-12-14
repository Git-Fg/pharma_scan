import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// Extension methods and utilities for Patrol E2E testing
///
/// This file provides additional functionality to make Patrol testing more
/// robust and maintainable for complex E2E scenarios.
extension PatrolTesterExtensions on PatrolIntegrationTester {
  // --- Enhanced Wait Methods ---

  /// Wait for network requests to complete
  Future<void> waitForNetworkRequests({Duration timeout = const Duration(seconds: 10)}) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      final loadingIndicators = [
        find.byType(CircularProgressIndicator),
        find.byType(LinearProgressIndicator),
        find.textContaining('Chargement'),
        find.textContaining('Loading'),
        find.textContaining('Veuillez patienter'),
        find.textContaining('Please wait'),
      ];

      bool hasLoadingIndicator = false;
      for (final indicator in loadingIndicators) {
        if (indicator.evaluate().isNotEmpty) {
          hasLoadingIndicator = true;
          break;
        }
      }

      if (!hasLoadingIndicator) {
        break;
      }

      await pump(const Duration(milliseconds: 100));
    }

    // Final pump and settle
    await pumpAndSettle();
  }

  /// Wait for a specific condition to be true
  Future<void> waitForCondition(
    Future<bool> Function() condition, {
    Duration timeout = const Duration(seconds: 30),
    String? timeoutMessage,
  }) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      if (await condition()) {
        return;
      }
      await pump(const Duration(milliseconds: 100));
    }

    throw TimeoutException(
      timeoutMessage ?? 'Condition not met within ${timeout.inSeconds} seconds',
      timeout,
    );
  }

  /// Wait for a widget to become tappable
  Future<void> waitForTappable(Finder finder, {Duration? timeout}) async {
    await waitFor(() async {
      try {
        final widget = tester.widget(finder);
        return widget is! StatefulWidget ||
               (widget is StatefulElement && widget.mounted);
      } catch (e) {
        return false;
      }
    }, timeout: timeout ?? const Duration(seconds: 10));

    await waitForWidgetToAppear(finder);
  }

  // --- Enhanced Permission Handling ---

  /// Handle all permission dialogs automatically
  Future<void> handlePermissionDialogs() async {
    while (await platform.mobile.isPermissionDialogVisible()) {
      await platform.mobile.grantPermissionWhenInUse();
      await pump(const Duration(milliseconds: 500));
    }
  }

  /// Handle specific permission type
  Future<void> handlePermissionDialog({bool grant = true}) async {
    if (await platform.mobile.isPermissionDialogVisible()) {
      if (grant) {
        await platform.mobile.grantPermissionWhenInUse();
      } else {
        await platform.mobile.denyPermission();
      }
      await pumpAndSettle();
    }
  }

  // --- Enhanced Interaction Methods ---

  /// Tap with scrolling if needed
  Future<void> tapWithScrolling(Finder finder, {double maxScrolls = 5}) async {
    int scrollAttempts = 0;

    while (finder.evaluate().isEmpty && scrollAttempts < maxScrolls) {
      // Scroll down
      final scrollable = find.byType(Scrollable).first;
      if (scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable, const Offset(0, -300));
        await pumpAndSettle();
      }
      scrollAttempts++;
    }

    if (finder.evaluate().isNotEmpty) {
      await tap(finder);
    } else {
      throw Exception('Widget not found after $maxScrolls scroll attempts');
    }
  }

  /// Safe tap that waits for widget to be ready
  Future<void> safeTap(Finder finder, {Duration? waitTimeout}) async {
    await waitForTappable(finder, timeout: waitTimeout);
    await tap(finder);
    await pumpAndSettle();
  }

  /// Enter text with clearing existing content
  Future<void> enterTextWithClear(Finder finder, String text) async {
    await tap(finder);
    await pumpAndSettle();

    // Clear existing text
    await tester.testTextInput.receiveAction(TextInputAction.selectAll);
    await tester.testTextInput.receiveAction(TextInputAction.delete);
    await pumpAndSettle();

    // Enter new text
    await tester.enterText(finder, text);
    await pumpAndSettle();
  }

  // --- Enhanced Scrolling Methods ---

  /// Scroll until a widget is found
  Future<void> scrollUntilFound(
    Finder targetFinder, {
    Finder? scrollableFinder,
    ScrollDirection direction = ScrollDirection.down,
    Duration timeout = const Duration(seconds: 30),
    double scrollDelta = 300.0,
  }) async {
    final scrollable = scrollableFinder ?? find.byType(Scrollable).first;
    if (scrollable.evaluate().isEmpty) {
      throw Exception('No scrollable widget found');
    }

    final endTime = DateTime.now().add(timeout);

    while (targetFinder.evaluate().isEmpty && DateTime.now().isBefore(endTime)) {
      final offset = direction == ScrollDirection.down
          ? Offset(0, -scrollDelta)
          : Offset(0, scrollDelta);

      await tester.drag(scrollable, offset);
      await pumpAndSettle();
    }

    if (targetFinder.evaluate().isEmpty) {
      throw Exception('Target widget not found after scrolling');
    }
  }

  /// Scroll to the bottom of a scrollable widget
  Future<void> scrollToBottom({Finder? customScrollable}) async {
    final scrollable = customScrollable ?? find.byType(Scrollable).first;
    if (scrollable.evaluate().isEmpty) return;

    // Scroll in large increments to reach bottom quickly
    for (int i = 0; i < 20; i++) {
      final scrollOffset = tester.renderObject(scrollable)?.paintBounds;
      if (scrollOffset == null) break;

      await tester.drag(scrollable, const Offset(0, -500));
      await pumpAndSettle();

      // Check if we've reached the bottom
      // This is a simplified check - you might need more sophisticated logic
      final currentOffset = tester.renderObject(scrollable)?.paintBounds;
      if (currentOffset != null && currentOffset == scrollOffset) {
        break;
      }
    }
  }

  /// Scroll to the top of a scrollable widget
  Future<void> scrollToTop({Finder? customScrollable}) async {
    final scrollable = customScrollable ?? find.byType(Scrollable).first;
    if (scrollable.evaluate().isEmpty) return;

    for (int i = 0; i < 20; i++) {
      await tester.drag(scrollable, const Offset(0, 500));
      await pumpAndSettle();
    }
  }

  // --- Enhanced Verification Methods ---

  /// Verify that a widget exists and is visible
  Future<bool> isWidgetVisible(Finder finder) async {
    try {
      await waitForWidgetToAppear(finder, timeout: const Duration(seconds: 5));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Verify that a widget contains specific text
  bool widgetContainsText(Finder finder, String text) {
    try {
      final widget = tester.widget(finder);
      if (widget is Text) {
        return widget.data?.toString().contains(text) ?? false;
      }
      // For other widget types, you might need more complex inspection
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Wait for a specific text to appear anywhere in the widget tree
  Future<void> waitForText(String text, {Duration? timeout}) async {
    final textFinder = find.text(text);
    await waitForWidgetToAppear(textFinder, timeout: timeout ?? defaultTimeout);
  }

  // --- Enhanced Debug Methods ---

  /// Print the current widget tree with optional filtering
  void debugPrintWidgetTree({String? filterText}) {
    final binding = tester.binding;
    print('=== Widget Tree Debug ===');

    if (filterText != null) {
      final filtered = binding.toStringDeep().split('\n')
          .where((line) => line.toLowerCase().contains(filterText.toLowerCase()))
          .join('\n');
      print(filtered);
    } else {
      print(binding.toStringDeep());
    }

    print('=== End Widget Tree ===');
  }

  /// Print all widgets of a specific type
  void debugPrintWidgetsOfType(Type widgetType) {
    final widgets = find.byType(widgetType).evaluate();
    print('=== Widgets of type $widgetType ===');

    for (int i = 0; i < widgets.length; i++) {
      final widget = tester.widget(widgets[i]);
      print('$i: $widget');
    }

    print('=== End $widgetType Widgets ===');
  }

  /// Print current navigation state
  void debugPrintNavigationState() {
    print('=== Navigation State ===');
    print('Current route: ${navigator.currentRoute?.settings.name}');
    print('Route stack length: ${navigator.currentState?.widget.pages.length}');
    print('=== End Navigation State ===');
  }

  // --- Gesture Utilities ---

  /// Perform a long press on a widget
  Future<void> longPress(Finder finder, {Duration duration = const Duration(milliseconds: 500)}) async {
    await tester.longPress(finder, duration: duration);
    await pumpAndSettle();
  }

  /// Perform a double tap on a widget
  Future<void> doubleTap(Finder finder) async {
    await doubleTap(finder);
    await pumpAndSettle();
  }

  /// Perform a drag gesture between two points
  Future<void> dragBetweenPoints(Offset start, Offset end, {Duration? duration}) async {
    await tester.dragFromPoint(start, end);
    await pumpAndSettle();
  }

  /// Perform a pinch gesture (zoom in)
  Future<void> pinchIn(Finder centerFinder, {double scale = 0.5}) async {
    final center = tester.getCenter(centerFinder);
    final size = tester.getSize(centerFinder);

    final initialPoint1 = center + Offset(-size.width / 4, -size.height / 4);
    final initialPoint2 = center + Offset(size.width / 4, size.height / 4);

    final finalPoint1 = center + Offset(-size.width / 8, -size.height / 8);
    final finalPoint2 = center + Offset(size.width / 8, size.height / 8);

    await tester.startGesture(initialPoint1);
    await tester.startGesture(initialPoint2);
    await pump();

    await tester.moveTo(finalPoint1);
    await tester.moveTo(finalPoint2);
    await pump();

    await tester.up();
    await tester.up();
    await pumpAndSettle();
  }

  /// Perform a pinch gesture (zoom out)
  Future<void> pinchOut(Finder centerFinder, {double scale = 2.0}) async {
    final center = tester.getCenter(centerFinder);
    final size = tester.getSize(centerFinder);

    final initialPoint1 = center + Offset(-size.width / 8, -size.height / 8);
    final initialPoint2 = center + Offset(size.width / 8, size.height / 8);

    final finalPoint1 = center + Offset(-size.width / 4, -size.height / 4);
    final finalPoint2 = center + Offset(size.width / 4, size.height / 4);

    await tester.startGesture(initialPoint1);
    await tester.startGesture(initialPoint2);
    await pump();

    await tester.moveTo(finalPoint1);
    await tester.moveTo(finalPoint2);
    await pump();

    await tester.up();
    await tester.up();
    await pumpAndSettle();
  }

  // --- Screen Utilities ---

  /// Take a screenshot with custom name
  Future<void> takeScreenshot(String name) async {
    try {
      await $.tester.binding.takeScreenshot(name);
      print('Screenshot taken: $name');
    } catch (e) {
      print('Failed to take screenshot: $e');
    }
  }

  /// Wait for and handle any snack bars that appear
  Future<void> handleAnySnackBar() async {
    await pumpAndSettle();

    final snackBars = find.byType(SnackBar);
    if (snackBars.evaluate().isNotEmpty) {
      // Take screenshot before dismissing
      await takeScreenshot('snackbar_before_dismiss');

      // Auto-dismiss after a short delay
      await Future.delayed(const Duration(seconds: 1));
      await pumpAndSettle();
    }
  }

  /// Wait for and handle any dialogs that appear
  Future<void> handleAnyDialog({bool accept = true}) async {
    await pumpAndSettle();

    final dialogs = find.byType(Dialog);
    if (dialogs.evaluate().isNotEmpty) {
      // Look for common dialog buttons
      final acceptButton = find.text('OK').first;
      final confirmButton = find.text('Confirmer').first;
      final yesButton = find.text('Oui').first;

      Finder buttonToTap = acceptButton;
      if (confirmButton.evaluate().isNotEmpty) {
        buttonToTap = confirmButton;
      } else if (yesButton.evaluate().isNotEmpty) {
        buttonToTap = yesButton;
      }

      if (accept || buttonToTap != acceptButton) {
        await tap(buttonToTap);
        await pumpAndSettle();
      }
    }
  }

  // --- Performance Testing Utilities ---

  /// Measure the time it takes to execute a function
  Future<T> measureTime<T>(Future<T> Function() function, String description) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await function();
      stopwatch.stop();

      print('$description took ${stopwatch.elapsedMilliseconds}ms');
      return result;
    } catch (e) {
      stopwatch.stop();
      print('$description failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }

  /// Wait for the app to be idle (no animations, loading, etc.)
  Future<void> waitForIdle({Duration timeout = const Duration(seconds: 10)}) async {
    final endTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(endTime)) {
      // Check if there are any pending animations or requests
      final hasAnimations = tester.binding.hasScheduledFrame;
      final hasLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
                         find.byType(LinearProgressIndicator).evaluate().isNotEmpty;

      if (!hasAnimations && !hasLoading) {
        break;
      }

      await pump(const Duration(milliseconds: 100));
    }

    // Final pump and settle
    await pumpAndSettle();
  }
}

/// Extension for Finder utilities
extension FinderExtensions on Finder {
  /// Check if finder exists and is visible
  bool get isVisible {
    return evaluate().isNotEmpty;
  }

  /// Get the first widget of this type
  T? getFirstWidget<T>() {
    try {
      return evaluate().first.widget as T?;
    } catch (e) {
      return null;
    }
  }

  /// Check if any widget contains specific text
  bool containsText(String text) {
    return evaluate().any((element) {
      try {
        final widget = element.widget;
        if (widget is Text) {
          return widget.data?.toString().contains(text) ?? false;
        }
        return false;
      } catch (e) {
        return false;
      }
    });
  }
}

/// Extension for Duration utilities
extension DurationExtensions on Duration {
  /// Get human readable duration
  String get humanReadable {
    if (inSeconds < 60) {
      return '${inSeconds}s';
    } else if (inMinutes < 60) {
      return '${inMinutes}m ${inSeconds % 60}s';
    } else {
      return '${inHours}h ${inMinutes % 60}m';
    }
  }
}

/// Extension for String utilities in testing
extension StringTestingExtensions on String {
  /// Check if string contains text ignoring case
  bool containsIgnoreCase(String other) {
    return toLowerCase().contains(other.toLowerCase());
  }

  /// Check if string equals text ignoring case
  bool equalsIgnoreCase(String other) {
    return toLowerCase() == other.toLowerCase();
  }

  /// Get a safe version for filenames (remove special chars)
  String get safeForFilename {
    return.replaceAll(RegExp(r'[^\w\-_.]'), '_');
  }
}