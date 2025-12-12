import 'package:azlistview/azlistview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'base_robot.dart';

/// Robot for Explorer/Database Search View interactions.
///
/// Encapsulates finders and actions for the explorer screen to keep tests clean.
class ExplorerRobot extends BaseRobot {
  ExplorerRobot(super.tester);

  Finder get _searchField => find.bySemanticsLabel(Strings.searchLabel);
  Finder get _indexBar => find.byType(IndexBar);

  /// Enters text into the search field.
  Future<void> enterSearch(String query) async {
    await tester.enterText(_searchField, query);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  /// Taps the search field to focus it.
  Future<void> tapSearchField() async {
    await tester.tap(_searchField);
    await tester.pump();
  }

  /// Taps a letter in the index bar to jump to that section.
  Future<void> tapIndexLetter(String letter) async {
    await tester.tap(
      find.descendant(of: _indexBar, matching: find.text(letter)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
  }

  /// Verifies the index bar is visible.
  void expectIndexBarVisible() {
    expect(_indexBar, findsOneWidget);
  }

  /// Verifies the index bar is hidden.
  void expectIndexBarHidden() {
    expect(_indexBar, findsNothing);
  }

  /// Verifies the search field is visible.
  void expectSearchFieldVisible() {
    expect(_searchField, findsOneWidget);
  }

  /// Verifies specific text appears in the results.
  void expectTextInResults(String text) {
    expect(find.text(text), findsOneWidget);
  }

  /// Verifies text does not appear in results.
  void expectTextNotInResults(String text) {
    expect(find.text(text), findsNothing);
  }

  /// Gets the screen height for layout verification.
  double getScreenHeight() {
    return tester.view.physicalSize.height / tester.view.devicePixelRatio;
  }

  /// Verifies search field stays within screen bounds when keyboard is open.
  void expectSearchFieldWithinBounds() {
    final screenHeight = getScreenHeight();
    final fieldRect = tester.getRect(_searchField);
    expect(fieldRect.bottom, lessThanOrEqualTo(screenHeight));
  }
}
