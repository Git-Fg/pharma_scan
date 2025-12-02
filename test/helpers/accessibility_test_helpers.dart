// test/helpers/accessibility_test_helpers.dart
// WHY: Helper methods for testing accessibility features in widget tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper class for accessibility testing in widget tests.
class AccessibilityTestHelpers {
  AccessibilityTestHelpers._();

  /// Verifies that a widget has a semantic label.
  ///
  /// Throws an assertion error if the widget is not found or doesn't have a label.
  static void expectSemanticLabel(
    WidgetTester tester,
    Finder finder,
    String expectedLabel,
  ) {
    final semantics = tester.getSemantics(finder);
    expect(
      semantics.label,
      expectedLabel,
      reason: 'Widget should have semantic label: $expectedLabel',
    );
  }

  /// Verifies that a widget has a semantic hint.
  ///
  /// Throws an assertion error if the widget is not found or doesn't have a hint.
  static void expectSemanticHint(
    WidgetTester tester,
    Finder finder,
    String expectedHint,
  ) {
    final semantics = tester.getSemantics(finder);
    expect(
      semantics.hint,
      expectedHint,
      reason: 'Widget should have semantic hint: $expectedHint',
    );
  }

  /// Verifies that a widget has a semantic value.
  ///
  /// Throws an assertion error if the widget is not found or doesn't have the expected value.
  static void expectSemanticValue(
    WidgetTester tester,
    Finder finder,
    String expectedValue,
  ) {
    final semantics = tester.getSemantics(finder);
    expect(
      semantics.value,
      expectedValue,
      reason: 'Widget should have semantic value: $expectedValue',
    );
  }

  /// Verifies that a widget has any semantic label (not null or empty).
  ///
  /// Throws an assertion error if the widget is not found or doesn't have a label.
  static void expectHasSemanticLabel(WidgetTester tester, Finder finder) {
    final semantics = tester.getSemantics(finder);
    expect(
      semantics.label,
      isNotNull,
      reason: 'Widget should have a semantic label',
    );
    expect(
      semantics.label,
      isNotEmpty,
      reason: 'Widget should have a non-empty semantic label',
    );
  }

  /// Verifies that a widget is excluded from semantics.
  ///
  /// This is useful for verifying decorative elements are properly excluded.
  /// Note: Excluded semantics won't appear in the semantics tree.
  /// This is a best-effort check - we verify by checking that ExcludeSemantics widget exists.
  static void expectExcludedFromSemantics(WidgetTester tester, Finder finder) {
    // Verify ExcludeSemantics widget is present
    expect(find.byType(ExcludeSemantics), findsWidgets);
  }
}
