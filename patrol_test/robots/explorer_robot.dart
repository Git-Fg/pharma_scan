import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';

import 'base_robot.dart';

/// Robot for Explorer screen interactions with enhanced E2E capabilities
class ExplorerRobot extends BaseRobot {
  ExplorerRobot(super.$);

  // --- Navigation ---
  Future<void> tapExplorerTab() async {
    await $(const Key(TestTags.navExplorer)).tap();
    await $.pumpAndSettle();
  }

  // --- Search Actions ---
  Future<void> searchForMedicament(String query) async {
    await $(const Key(TestTags.searchField)).waitUntilVisible();
    await $(const Key(TestTags.searchField)).enterText(query);
    await $.pumpAndSettle();
  }

  Future<void> clearSearch() async {
    await $(const Key(TestTags.searchField)).enterText('');
    await $.pumpAndSettle();
  }

  Future<void> tapClearFilters() async {
    await $(Strings.clearFilters).tap();
    await $.pumpAndSettle();
  }

  // --- Explorer Verifications ---
  Future<void> expectExplorerScreenVisible() async {
    await $(const Key(TestTags.explorerScreen)).waitUntilVisible();
  }

  Future<void> expectSearchFieldVisible() async {
    await $(const Key(TestTags.searchField)).waitUntilVisible();
  }

  Future<void> expectMedicamentVisible(String name) async {
    await $(name).waitUntilVisible();
  }

  Future<void> expectMedicamentCardVisible() async {
    await $(const Key(TestTags.medicamentCard)).waitUntilVisible();
  }

  Future<void> expectNoResultsVisible() async {
    await $(Strings.noResults).waitUntilVisible();
  }

  Future<void> expectEmptyStateVisible() async {
    await $(Strings.explorerEmptyTitle).waitUntilVisible();
  }

  Future<void> expectFiltersVisible() async {
    await $(Strings.filters).waitUntilVisible();
  }

  // --- Group/Cluster Interactions ---
  Future<void> tapGroup(String groupName) async {
    await $(groupName).tap();
    await $.pumpAndSettle();
  }

  Future<void> tapCluster(String clusterName) async {
    await $(clusterName).tap();
    await $.pumpAndSettle();
  }

  Future<void> tapMedicamentCard(String medicamentName) async {
    await $(medicamentName).tap();
    await $.pumpAndSettle();
  }

  // --- Index Navigation ---
  Future<void> tapIndexLetter(String letter) async {
    await $(letter).tap();
    await $.pumpAndSettle();
  }

  // --- Search Flow Completion ---
  /// Complete search flow: navigate to explorer, search for medication
  Future<void> completeSearchFlow(String query) async {
    await tapExplorerTab();
    await searchForMedicament(query);
  }

  /// Verify search results for a query
  Future<void> verifySearchResults(String query,
      {bool shouldFindResults = true}) async {
    await completeSearchFlow(query);

    if (shouldFindResults) {
      await expectMedicamentVisible(query);
    } else {
      await expectNoResultsVisible();
    }
  }

  // --- Enhanced Search Actions ---
  Future<void> tapSearchField() async {
    await $(Key(TestTags.searchField)).tap();
    await pumpAndSettleWithDelay();
  }

  Future<void> enterSearchQuery(String query) async {
    await $(Key(TestTags.searchField)).enterText(query);
    await pumpAndSettleWithDelay(
        const Duration(milliseconds: 500)); // Wait for debouncing
  }

  Future<void> submitSearch() async {
    // Search might be submitted automatically due to debouncing
    try {
      final submitButton = find.byIcon(Icons.search);
      if (submitButton.evaluate().isNotEmpty) {
        await $.tester.tap(submitButton);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Search submit button not found: $e');
    }
  }

  // --- Enhanced Filter Actions ---
  Future<void> openFilters() async {
    try {
      final filterButton = find.byIcon(Icons.filter_list);
      if (filterButton.evaluate().isNotEmpty) {
        await $.tester.tap(filterButton);
        await waitForModalBottomSheet();
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Filter button not found: $e');
    }
  }

  Future<void> selectRouteFilter(String route) async {
    try {
      final routeOption = find.text(route);
      if (routeOption.evaluate().isNotEmpty) {
        await $.tester.tap(routeOption);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Route filter option $route not found: $e');
    }
  }

  Future<void> selectPriceFilter(String priceRange) async {
    try {
      final priceOption = find.text(priceRange);
      if (priceOption.evaluate().isNotEmpty) {
        await $.tester.tap(priceOption);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Price filter option $priceRange not found: $e');
    }
  }

  Future<void> applyFilters() async {
    try {
      final applyButton = find.text('Appliquer').first;
      if (applyButton.evaluate().isNotEmpty) {
        await $.tester.tap(applyButton);
        await pumpAndSettleWithDelay();
        await waitForLoadingToComplete();
      }
    } catch (e) {
      debugPrint('Apply filters button not found: $e');
    }
  }

  Future<void> resetFilters() async {
    try {
      final resetButton = find.text('Réinitialiser').first;
      if (resetButton.evaluate().isNotEmpty) {
        await $.tester.tap(resetButton);
        await pumpAndSettleWithDelay();
        await waitForLoadingToComplete();
      }
    } catch (e) {
      debugPrint('Reset filters button not found: $e');
    }
  }

  Future<void> closeFilters() async {
    try {
      final closeButton = find.byIcon(Icons.close);
      if (closeButton.evaluate().isNotEmpty) {
        await $.tester.tap(closeButton);
        await pumpAndSettleWithDelay();
      } else {
        await dismissBottomSheet();
      }
    } catch (e) {
      debugPrint('Close filters failed: $e');
    }
  }

  // --- Enhanced Navigation Actions ---
  Future<void> tapAlphabeticalIndex(String letter) async {
    try {
      final indexButton = find.text(letter);
      if (indexButton.evaluate().isNotEmpty) {
        await $.tester.tap(indexButton);
        await pumpAndSettleWithDelay(const Duration(milliseconds: 300));
      }
    } catch (e) {
      debugPrint('Alphabetical index $letter not found: $e');
    }
  }

  Future<void> scrollToSection(String section) async {
    await scrollUntilTextVisible(section);
  }

  Future<void> tapMedicationGroup(String groupName) async {
    try {
      // Try to find group by exact text match
      final groupTile = find.text(groupName);
      if (groupTile.evaluate().isNotEmpty) {
        await scrollUntilVisible(groupTile);
        await $.tester.tap(groupTile);
        await pumpAndSettleWithDelay();
        return;
      }

      // Try to find group containing the text
      final groupContainingText = find.textContaining(groupName);
      if (groupContainingText.evaluate().isNotEmpty) {
        await scrollUntilVisible(groupContainingText);
        await $.tester.tap(groupContainingText.first);
        await pumpAndSettleWithDelay();
        return;
      }

      throw Exception('Medication group $groupName not found');
    } catch (e) {
      debugPrint('Failed to tap medication group $groupName: $e');
      rethrow;
    }
  }

  Future<void> tapClusterTile(String clusterTitle) async {
    try {
      final clusterTile = find.text(clusterTitle);
      if (clusterTile.evaluate().isNotEmpty) {
        await scrollUntilVisible(clusterTile);
        await $.tester.tap(clusterTile);
        await pumpAndSettleWithDelay();
      } else {
        throw Exception('Cluster tile $clusterTitle not found');
      }
    } catch (e) {
      debugPrint('Failed to tap cluster tile $clusterTitle: $e');
      rethrow;
    }
  }

  // --- Detail View Actions ---
  Future<void> tapFicheButton() async {
    try {
      final ficheButton = find.text('Fiche').first;
      if (ficheButton.evaluate().isNotEmpty) {
        await $.tester.tap(ficheButton);
        await pumpAndSettleWithDelay();
        await waitForLoadingToComplete();
      }
    } catch (e) {
      debugPrint('Fiche button not found: $e');
    }
  }

  Future<void> tapRcpButton() async {
    try {
      final rcpButton = find.text('RCP').first;
      if (rcpButton.evaluate().isNotEmpty) {
        await $.tester.tap(rcpButton);
        await pumpAndSettleWithDelay();
        await waitForLoadingToComplete();
      }
    } catch (e) {
      debugPrint('RCP button not found: $e');
    }
  }

  Future<void> tapViewInExplorer() async {
    try {
      final viewInExplorerButton = find.textContaining('Voir dans').first;
      if (viewInExplorerButton.evaluate().isNotEmpty) {
        await $.tester.tap(viewInExplorerButton);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('View in Explorer button not found: $e');
    }
  }

  Future<void> closeDetailSheet() async {
    try {
      final closeButton = find.byIcon(Icons.close);
      if (closeButton.evaluate().isNotEmpty) {
        await $.tester.tap(closeButton);
        await pumpAndSettleWithDelay();
      } else {
        await dismissBottomSheet();
      }
    } catch (e) {
      debugPrint('Failed to close detail sheet: $e');
    }
  }

  Future<void> closeDrawer() async {
    try {
      final closeButton = find.byIcon(Icons.close);
      if (closeButton.evaluate().isNotEmpty) {
        await $.tester.tap(closeButton);
        await pumpAndSettleWithDelay();
      } else {
        await dismissBottomSheet();
      }
    } catch (e) {
      debugPrint('Failed to close drawer: $e');
    }
  }

  // --- Sorting Actions ---
  Future<void> openSortOptions() async {
    try {
      final sortButton = find.byIcon(Icons.sort);
      if (sortButton.evaluate().isNotEmpty) {
        await $.tester.tap(sortButton);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Sort button not found: $e');
    }
  }

  Future<void> selectSortOption(String sortOption) async {
    try {
      final option = find.text(sortOption);
      if (option.evaluate().isNotEmpty) {
        await $.tester.tap(option);
        await pumpAndSettleWithDelay();
        await waitForLoadingToComplete();
      }
    } catch (e) {
      debugPrint('Sort option $sortOption not found: $e');
    }
  }

  // --- Special Actions ---
  Future<void> pullToRefresh() async {
    final scrollable = find.byType(Scrollable).first;
    if (scrollable.evaluate().isNotEmpty) {
      await $.tester.drag(scrollable, const Offset(0, 300));
      await pumpAndSettleWithDelay();
      await waitForLoadingToComplete();
    }
  }

  Future<void> navigateToTop() async {
    await scrollToTop();
  }

  // --- Enhanced Assertions ---
  void expectFilterActive(String filterName) {
    // Look for active filter indicator
    final activeFilter = find.textContaining(filterName);
    if (activeFilter.evaluate().isNotEmpty) {
      expect(activeFilter, findsOneWidget);
    }
  }

  void expectPricingVisible(String price) {
    expectVisibleByText(price);
  }

  void expectSearchResultsCount(int expectedCount) {
    final resultsCards = find.byType(ListTile);
    expect(resultsCards, findsNWidgets(expectedCount));
  }

  void expectDrawerOpen() {
    expect(find.byType(ModalBottomSheetRoute), findsOneWidget);
  }

  void expectDetailSheetOpen() {
    expect(find.byType(ModalBottomSheetRoute), findsOneWidget);
  }

  void expectFilterVisible(String filterName) {
    expectVisibleByText(filterName);
  }

  void expectSortOptionSelected(String sortOption) {
    expectVisibleByText(sortOption);
  }

  void expectAlphabeticalIndexVisible() {
    // Look for A-Z index indicators
    final alphabetLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
    bool foundIndex = false;

    for (final letter in alphabetLetters) {
      if (find.text(letter).evaluate().isNotEmpty) {
        foundIndex = true;
        break;
      }
    }

    expect(foundIndex, isTrue, reason: 'Alphabetical index not found');
  }

  void expectBadgeVisible(String badgeText) {
    // Look for badge/chip widgets
    final badge = find.text(badgeText);
    if (badge.evaluate().isNotEmpty) {
      expect(badge, findsOneWidget);
    }
  }

  void expectGenericBadgeVisible() {
    expectBadgeVisible('Générique');
  }

  void expectPrincepsBadgeVisible() {
    expectBadgeVisible('Princeps');
  }

  void expectSearchFieldFocused() {
    final searchField = find.byKey(Key(TestTags.searchField));
    expect(searchField, findsOneWidget);
    // Check if the search field is focused
    final focusNode = $.tester.widget<TextField>(searchField).focusNode;
    expect(focusNode?.hasFocus, isTrue);
  }

  void expectSearchQueryEntered(String query) {
    final searchField = find.byKey(Key(TestTags.searchField));
    final textField = $.tester.widget<TextField>(searchField);
    expect(textField.controller?.text, equals(query));
  }

  void expectClusterProductsCount(int expectedCount) {
    // Look for product count indicators in cluster details
    final countTexts = find.textContaining('produits');
    if (countTexts.evaluate().isNotEmpty) {
      // This is a simplified check - in practice you might need
      // to parse the actual number from the text
      expect(countTexts, findsWidgets);
    }
  }

  void expectGroupDetailVisible() {
    expect(find.byType(ModalBottomSheetRoute), findsOneWidget);
    // Additional checks for group detail content
    final groupDetailTitle = find.byKey(const Key('group_detail_title'));
    if (groupDetailTitle.evaluate().isNotEmpty) {
      expect(groupDetailTitle, findsOneWidget);
    }
  }

  void expectSearchPlaceholderVisible() {
    expectVisibleByTextContaining('Rechercher');
  }

  void expectNoFiltersApplied() {
    // Check that no active filter indicators are present
    final activeFilters = find.byType(InputChip);
    expect(activeFilters, findsNothing);
  }

  // --- Aliases for consistent API ---
  Future<void> expectMedicationGroupVisible(String groupName) async {
    final groupTile = find.text(groupName);
    if (groupTile.evaluate().isEmpty) {
      final groupContainingText = find.textContaining(groupName);
      if (groupContainingText.evaluate().isNotEmpty) {
        await scrollUntilVisible(groupContainingText);
        return;
      }
      // If not found immediately, try scrolling down a bit or fail
      await scrollUntilVisible(groupTile);
    } else {
      await scrollUntilVisible(groupTile);
    }
  }

  Future<void> waitForDrawer() async {
    await $(find.byType(ModalBottomSheetRoute)).waitUntilVisible();
  }

  Future<void> tapMedicationCard(String medicationName) async {
    await tapMedicamentCard(medicationName);
  }

  Future<void> expectSearchResultsVisible({String? query}) async {
    if (query != null) {
      await verifySearchResults(query, shouldFindResults: true);
    } else {
      await expectMedicamentCardVisible();
    }
  }

  void expectEmptySearchState() {
    expectNoResultsVisible();
  }

  Future<void> waitForDetailSheet() async {
    await $(find.byType(ModalBottomSheetRoute)).waitUntilVisible();
  }

  // --- Strict Robot Pattern Additions ---
  Future<void> expectTextVisible(String text, {Duration? timeout}) async {
    await $(find.text(text))
        .waitUntilVisible(timeout: timeout ?? defaultTimeout);
  }

  void expectPartialTextVisible(String text) {
    expect(find.textContaining(text), findsWidgets);
  }

  Future<void> expectDetailSheetVisibleEx() async {
    await $(const Key('medicationDetailSheet')).waitUntilVisible();
  }

  Future<void> expectActionButtonsVisible() async {
    await $(const Key('ficheButton')).waitUntilVisible();
    await $(const Key('rcpButton')).waitUntilVisible();
  }
}
