import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'base_robot.dart';

/// Robot for Explorer/Database Search View interactions.
///
/// Encapsulates finders and actions for the explorer screen to keep tests clean.
/// Enhanced with golden database search flow testing capabilities.
class ExplorerRobot extends BaseRobot {
  ExplorerRobot(super.tester);

  Finder get _searchField => find.bySemanticsLabel(Strings.searchLabel);
  Finder get _indexBar => find.byType(IndexBar);
  Finder get _listView => find.byType(ListView);
  Finder get _listTile => find.byType(ListTile);

  /// Main search method following the "Golden Path" approach.
  /// Combines tap, clear, and enter for a complete search action.
  Future<void> search(String query) async {
    // Tap on the search field to focus it
    await tapSearchField();

    // Clear existing text and enter new query
    await tester.enterText(_searchField, '');
    await tester.enterText(_searchField, query);

    // Wait for search results to load
    await pump(const Duration(seconds: 1));
    await pumpAndSettle();
  }

  /// Enters text into the search field (legacy method).
  Future<void> enterSearch(String query) async {
    await tester.enterText(_searchField, query);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  /// Taps the search field to focus it.
  Future<void> tapSearchField() async {
    await tester.tap(_searchField);
    await pump(const Duration(milliseconds: 100));
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

  /// Verifies that search results are displayed and returns the count.
  ///
  /// Usage:
  /// ```dart
  /// final count = robot.verifyResultCount(greaterThanZero: true);
  /// ```
  int verifyResultCount({bool greaterThanZero = false, int? exactCount}) {
    if (exactCount != null) {
      expect(_listView, findsOneWidget,
          reason: 'Should display a ListView with search results');
      expect(_listTile.evaluate().length, exactCount,
          reason: 'Should display exactly $exactCount results');
    }

    if (greaterThanZero) {
      expect(_listView, findsOneWidget,
          reason: 'Should display search results');
      expect(_listTile, findsWidgets,
          reason: 'Should display search result items');
    }

    return _listTile.evaluate().length;
  }

  /// Taps on the first search result.
  ///
  /// This action should navigate to the medication detail page or group view.
  Future<void> tapFirstResult() async {
    expect(_listTile, findsWidgets,
        reason: 'Should have search results to tap');
    await tester.tap(_listTile.first);
    await pumpAndSettle();
  }

  /// Verifies that no results are displayed (empty state).
  void verifyNoResults() {
    expect(
      find.text('Aucun résultat'),
      findsOneWidget,
      reason: 'Should show "Aucun résultat" when no search results are found',
    );
    expect(
      _listTile,
      findsNothing,
      reason: 'Should not display any result items',
    );
  }

  /// Performs a search and verifies results in one step.
  Future<int> searchAndVerify(String query,
      {bool greaterThanZero = false}) async {
    await search(query);
    return verifyResultCount(greaterThanZero: greaterThanZero);
  }

  /// Searches for a medication and taps the first result.
  ///
  /// This combines searching with navigation verification.
  Future<void> searchAndTapFirst(String query) async {
    await search(query);
    await tapFirstResult();
  }

  /// Verifies that the search results contain expected text.
  void verifyResultsContain(String expectedText) {
    expect(
      find.textContaining(expectedText),
      findsWidgets,
      reason: 'Search results should contain: $expectedText',
    );
  }

  /// Performs step-by-step typing to test real-time search updates.
  Future<void> testRealTimeSearch(List<String> typingSteps) async {
    await tapSearchField();

    for (final step in typingSteps) {
      await tester.enterText(_searchField, step);
      await pump(const Duration(milliseconds: 500)); // Wait for search debounce
      await pumpAndSettle();
    }
  }

  /// Clears the search field completely.
  Future<void> clearSearch() async {
    await tapSearchField();
    await tester.enterText(_searchField, '');
    await pumpAndSettle();
  }

  /// Gets the current text in the search field.
  String getSearchText() {
    return tester.widget<TextField>(_searchField).controller?.value.text ?? '';
  }

  /// Verifies that the search completed successfully and results are loaded.
  void expectSearchCompleted() {
    expect(
      _listView,
      findsOneWidget,
      reason: 'Search should complete and show results',
    );
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'Should not show loading indicator after search completes',
    );
  }
}
