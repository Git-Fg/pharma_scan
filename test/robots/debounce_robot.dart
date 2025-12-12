import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'base_robot.dart';

/// Robot for debounced controller widget interactions.
///
/// Encapsulates finders and actions for testing debounced text input.
class DebounceRobot extends BaseRobot {
  DebounceRobot(super.tester);

  Finder get _inputField => find.byKey(const Key('debounce-input'));
  Finder get _debouncedValue => find.byKey(const Key('debounce-value'));

  /// Enters text into the debounced input field.
  Future<void> enterText(String text) async {
    await tester.enterText(_inputField, text);
    await tester.pump();
  }

  /// Expects the debounced value to match the given text.
  void expectDebouncedValue(String expectedValue) {
    expect(
      tester.widget<Text>(_debouncedValue).data,
      expectedValue,
    );
  }

  /// Pumps with a specific duration (for testing debounce timing).
  Future<void> pumpDuration(Duration duration) async {
    await pump(duration);
  }
}
