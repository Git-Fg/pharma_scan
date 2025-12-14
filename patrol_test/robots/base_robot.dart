import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// Base robot class providing common utilities and methods for all E2E test robots.
///
/// This class serves as the foundation for the Page Object Model pattern,
/// offering shared functionality like waiting, scrolling, and common assertions.
abstract class BaseRobot {
  final PatrolIntegrationTester $;

  BaseRobot(this.$);

  // Common timeouts
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration shortTimeout = Duration(seconds: 10);
  static const Duration mediumTimeout = Duration(seconds: 20);
  static const Duration longTimeout = Duration(seconds: 45);

  // Common waits
  Future<void> waitForAppToLoad() async {
    await $.pumpAndSettle(mediumTimeout);
    // Wait for any initial animations or loading states
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> pumpAndSettleWithDelay([Duration? delay]) async {
    await $.pumpAndSettle();
    await Future.delayed(delay ?? const Duration(milliseconds: 300));
  }

  Future<void> waitForWidgetToAppear(Key key, {Duration? timeout}) async {
    await $(key).waitUntilVisible(timeout: timeout ?? defaultTimeout);
  }

  Future<void> waitForTextToAppear(String text, {Duration? timeout}) async {
    await $(text).waitUntilVisible(timeout: timeout ?? defaultTimeout);
  }

  Future<void> waitForWidgetToDisappear(Key key, {Duration? timeout}) async {
    await $(key).waitUntilGone(timeout: timeout ?? defaultTimeout);
  }

  // Common scrolling utilities
  Future<void> scrollUntilVisible(
    Finder finder, {
    ScrollDirection direction = ScrollDirection.down,
    Duration? timeout,
    double delta = 300.0,
  }) async {
    final scrollable = find.byType(Scrollable);

    if (scrollable.evaluate().isEmpty) {
      throw Exception('No scrollable widget found');
    }

    bool isVisible() {
      return finder.evaluate().isNotEmpty;
    }

    if (isVisible()) return;

    final endTime = DateTime.now().add(timeout ?? mediumTimeout);

    while (!isVisible() && DateTime.now().isBefore(endTime)) {
      await $.tester.drag(
        scrollable,
        Offset(0, direction == ScrollDirection.down ? -delta : delta),
      );
      await $.pumpAndSettle();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!isVisible()) {
      throw Exception('Widget not found after scrolling');
    }
  }

  Future<void> scrollUntilTextVisible(
    String text, {
    ScrollDirection direction = ScrollDirection.down,
    Duration? timeout,
  }) async {
    await scrollUntilVisible(
      find.text(text),
      direction: direction,
      timeout: timeout,
    );
  }

  Future<void> scrollToTop({Finder? customScrollable}) async {
    final scrollable = customScrollable ?? find.byType(Scrollable);

    if (scrollable.evaluate().isEmpty) return;

    // Scroll up in larger increments to ensure we reach the top
    for (int i = 0; i < 10; i++) {
      await $.tester.drag(scrollable, const Offset(0, 500));
      await $.pumpAndSettle();
    }
  }

  Future<void> scrollToBottom({Finder? customScrollable}) async {
    final scrollable = customScrollable ?? find.byType(Scrollable);

    if (scrollable.evaluate().isEmpty) return;

    // Scroll down in larger increments to ensure we reach the bottom
    for (int i = 0; i < 10; i++) {
      await $.tester.drag(scrollable, const Offset(0, -500));
      await $.pumpAndSettle();
    }
  }

  // Common assertions
  void expectVisible(String keyOrText) {
    if (keyOrText.startsWith('#')) {
      expect($(Key(keyOrText.substring(1))), findsOneWidget);
    } else {
      expect($(keyOrText), findsOneWidget);
    }
  }

  void expectVisibleByKeyString(String key) {
    expect($(Key(key)), findsOneWidget);
  }

  void expectNotVisible(String keyOrText) {
    if (keyOrText.startsWith('#')) {
      expect($(Key(keyOrText.substring(1))), findsNothing);
    } else {
      expect($(keyOrText), findsNothing);
    }
  }

  void expectVisibleByKeyWidget(Key key) {
    expect($(key), findsOneWidget);
  }

  void expectNotVisibleByKeyWidget(Key key) {
    expect($(key), findsNothing);
  }

  void expectVisibleByText(String text) {
    expect($(text), findsOneWidget);
  }

  void expectNotVisibleByText(String text) {
    expect($(text), findsNothing);
  }

  void expectVisibleByValueKey(String key) {
    expect($.tester.widget(find.byKey(ValueKey(key))), isNotNull);
  }

  // Common interactions
  Future<void> tapButton(String text) async {
    await $(text).tap();
    await pumpAndSettleWithDelay();
  }

  Future<void> tapButtonByKey(String key) async {
    await $(Key(key)).tap();
    await pumpAndSettleWithDelay();
  }

  Future<void> enterText(String text) async {
    await $.tester.enterText(find.byType(TextField), text);
    await pumpAndSettleWithDelay();
  }

  Future<void> enterTextByKey(String key, String text) async {
    await $.tester.enterText(find.byKey(ValueKey(key)), text);
    await pumpAndSettleWithDelay();
  }

  Future<void> clearText() async {
    await $.tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpAndSettleWithDelay();
  }

  Future<void> clearTextByKey(String key) async {
    final textField = find.byKey(ValueKey(key));
    await $.tester.tap(textField);
    await $.tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpAndSettleWithDelay();
  }

  // Common utilities for handling dialogs and sheets
  Future<void> waitForBottomSheet() async {
    await $.pumpAndSettle();
    await find.byType(BottomSheet).waitUntilVisible();
  }

  Future<void> waitForModalBottomSheet() async {
    await $.pumpAndSettle();
    await find.byType(ModalBottomSheetRoute).waitUntilVisible();
  }

  Future<void> waitForDialog() async {
    await $.pumpAndSettle();
    await find.byType(Dialog).waitUntilVisible();
  }

  Future<void> dismissBottomSheet() async {
    await $.tester.tapAt(const Offset(50, 50)); // Tap outside to dismiss
    await pumpAndSettleWithDelay();
  }

  Future<void> dismissDialog() async {
    if (find.byType(AlertDialog).evaluate().isNotEmpty) {
      await $.tester.tap(find.text('OK').first);
      await pumpAndSettleWithDelay();
    }
  }

  // Utility for handling loading states
  Future<void> waitForLoadingToComplete({Duration? timeout}) async {
    final endTime = DateTime.now().add(timeout ?? longTimeout);

    while (DateTime.now().isBefore(endTime)) {
      final isLoading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
                       find.byType(LinearProgressIndicator).evaluate().isNotEmpty;

      if (!isLoading) break;

      await $.pumpAndSettle(const Duration(milliseconds: 100));
    }
  }

  // Utility for handling snack bars and toasts
  Future<void> waitForSnackBar(String? message) async {
    await $.pumpAndSettle();

    if (message != null) {
      await $(message).waitUntilVisible(timeout: shortTimeout);
    } else {
      await find.byType(SnackBar).waitUntilVisible(timeout: shortTimeout);
    }
  }

  // Debug utilities
  void debugPrintCurrentWidgetTree() {
    debugPrint('=== Current Widget Tree ===');
    debugPrint($.tester.binding.toStringDeep());
    debugPrint('=== End Widget Tree ===');
  }

  void debugPrintAllWidgets() {
    final widgets = $.tester.binding.renderObjectOwner.rebuildScope?.debugDiagnosticNodes ?? [];
    for (final widget in widgets) {
      debugPrint(widget.toString());
    }
  }
}

enum ScrollDirection {
  up,
  down,
  left,
  right,
}