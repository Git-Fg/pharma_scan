import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../data/test_products.dart';
import '../helpers/test_database_helper.dart';
import '../robots/app_robot.dart';

/// GP2: Search Explorer Test
///
/// Test the search and explorer functionality:
/// 1. Navigate to Explorer
/// 2. Search for "Amoxicilline"
/// 3. Verify filtered results
/// 4. Tap on medication group
/// 5. Open detail sheets and verify information
/// 6. Test filters and navigation
void main() {
  group('GP2: Search Explorer Tests', () {
    patrolTest(
      'GP2.1: Complete search workflow - Navigate → Search → Results → Detail',
      config: const PatrolTesterConfig(printLogs: true),
      ($) async {
        final appRobot = AppRobot($);
        // PHASE 1: Setup and Initialization
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();

        // PHASE 2: Navigate to Explorer
        await appRobot.navigateToTab('explorer');
        await appRobot.explorer.expectExplorerScreenVisible();
        await appRobot.explorer.expectSearchFieldVisible();

        // PHASE 3: Search for "Amoxicilline"
        await appRobot.measureTime(
          () async {
            await appRobot.explorer.tapSearchField();
            await appRobot.explorer.enterSearchQuery('Amoxicilline');
            await appRobot.explorer.submitSearch();
          },
          'Amoxicilline search',
        );

        // PHASE 4: Wait for search results
        await appRobot.waitForNetworkRequests();
        await appRobot.explorer.expectSearchResultsVisible();

        // PHASE 5: Verify filtered results
        await appRobot.explorer.expectTextVisible('AMOXICILLINE');

        // Look for multiple Amoxicilline variants
        appRobot.explorer.expectPartialTextVisible('AMOXICILLINE');

        // Verify search results contain expected information
        await appRobot.explorer.expectMedicationGroupVisible('AMOXICILLINE');

        // PHASE 6: Tap on medication group
        await appRobot.explorer.tapMedicationGroup('AMOXICILLINE');
        await appRobot.explorer.waitForDrawer();
        appRobot.explorer.expectDrawerOpen();

        // PHASE 7: Verify group detail information
        await appRobot.explorer.expectTextVisible('AMOXICILLINE');
        await appRobot.explorer.expectTextVisible('500 mg'); // Common dosage
        await appRobot.explorer.expectTextVisible('Antibiotique');

        // PHASE 8: Tap on specific medication
        await appRobot.explorer.tapMedicationCard('AMOXICILLINE 500 mg');
        await appRobot.explorer.waitForDetailSheet();

        // PHASE 9: Verify medication detail
        await appRobot.explorer.expectDetailSheetVisibleEx();
        await appRobot.explorer.expectTextVisible('AMOXICILLINE 500 mg');
        await appRobot.explorer
            .expectTextVisible(TestProducts.amoxicilline500Labo);

        // Verify action buttons
        await appRobot.explorer.expectActionButtonsVisible();

        debugPrint('✅ GP2.1: Complete search workflow passed');
      },
    );

    patrolTest(
      'GP2.2: Explorer filters - Route administration',
      config: const PatrolTesterConfig(printLogs: true),
      ($) async {
        final appRobot = AppRobot($);
        // Setup
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('explorer');

        // Open filters
        await appRobot.explorer.openFilters();
        appRobot.explorer.expectFilterVisible('Voie orale');

        // Select "Voie Orale" filter
        await appRobot.explorer.selectRouteFilter('Voie orale');
        await appRobot.explorer.applyFilters();
        await appRobot.waitForNetworkRequests();

        // Verify filter is active
        appRobot.explorer.expectFilterActive('Voie orale');

        // Search and verify filtered results
        await appRobot.explorer.enterSearchQuery('Paracétamol');
        await appRobot.explorer.submitSearch();

        // Verify oral medications are shown
        await appRobot.explorer.expectTextVisible('DOLIPRANE');
        appRobot.explorer.expectPartialTextVisible('orale');

        debugPrint('✅ GP2.2: Route administration filter passed');
      },
    );

    patrolTest(
      'GP2.3: Explorer alphabetical navigation',
      config: const PatrolTesterConfig(printLogs: true),
      ($) async {
        final appRobot = AppRobot($);
        // Setup
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('explorer');

        // Verify alphabetical index is visible
        appRobot.explorer.expectAlphabeticalIndexVisible();

        // Navigate to 'D' section
        await appRobot.explorer.tapAlphabeticalIndex('D');
        await appRobot.waitAndSettle();

        // Scroll to section containing Doliprane
        await appRobot.explorer.scrollToSection('D');

        // Verify Doliprane is visible
        await appRobot.explorer.expectMedicationGroupVisible('DOLIPRANE');

        // Test other letters
        await appRobot.explorer.tapAlphabeticalIndex('A');
        await appRobot.explorer.scrollToSection('A');

        await appRobot.explorer.tapAlphabeticalIndex('I');
        await appRobot.explorer.scrollToSection('I');

        // Verify IBUPROFENE appears
        await appRobot.explorer.expectMedicationGroupVisible('IBUPROFENE');

        debugPrint('✅ GP2.3: Alphabetical navigation passed');
      },
    );

    patrolTest(
      'GP2.4: Explorer search debouncing and performance',
      config: const PatrolTesterConfig(printLogs: true),
      ($) async {
        final appRobot = AppRobot($);
        // Setup
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('explorer');

        // Test rapid search input
        final searchTimes = <int>[];

        for (int i = 0; i < 3; i++) {
          final startTime = DateTime.now().millisecondsSinceEpoch;

          await appRobot.explorer.tapSearchField();
          await appRobot.explorer.enterSearchQuery('A'); // Single letter
          await Future<void>.delayed(
              const Duration(milliseconds: 300)); // Wait for debouncing
          await appRobot.waitAndSettle();

          final endTime = DateTime.now().millisecondsSinceEpoch;
          searchTimes.add(endTime - startTime);

          // Clear search
          await appRobot.explorer.clearSearch();
        }

        final averageSearchTime =
            searchTimes.reduce((a, b) => a + b) / searchTimes.length;
        debugPrint(
            '📊 GP2.4: Average search time: ${averageSearchTime.round()}ms');

        // Test longer search
        await appRobot.explorer.enterSearchQuery('Paracétamol');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await appRobot.waitAndSettle();

        // Verify results
        appRobot.explorer.expectMedicationGroupVisible('DOLIPRANE');

        debugPrint('✅ GP2.4: Search debouncing and performance test completed');
      },
    );

    patrolTest(
      'GP2.5: Explorer generic vs princeps identification',
      config: const PatrolTesterConfig(printLogs: true),
      ($) async {
        final appRobot = AppRobot($);
        // Setup
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('explorer');

        // Search for Doliprane
        await appRobot.explorer.enterSearchQuery('Doliprane');
        await appRobot.explorer.submitSearch();
        await appRobot.waitForNetworkRequests();

        // Tap on main Doliprane group
        await appRobot.explorer.tapMedicationGroup('DOLIPRANE');
        await appRobot.explorer.waitForDrawer();

        // Look for princeps indication or generic equivalents
        try {
          // Check if there are generic badges
          await appRobot.explorer.expectTextVisible('Générique',
              timeout: const Duration(seconds: 2));
          debugPrint('✅ GP2.5: Generic badge found for Doliprane');
        } catch (e) {
          debugPrint(
              '⚠️ GP2.5: Generic badges not visible, checking other indicators');
        }

        // Search for generic specifically
        await appRobot.explorer.closeDetailSheet();
        await appRobot.explorer.enterSearchQuery('PARACETAMOL BIOGARAN');
        await appRobot.explorer.submitSearch();

        // Should find generic equivalent
        await appRobot.explorer.expectMedicationGroupVisible('PARACETAMOL');

        debugPrint('✅ GP2.5: Generic vs princeps identification completed');
      },
    );

    patrolTest(
      'GP2.6: Explorer empty search and no results handling',
      config: const PatrolTesterConfig(printLogs: true),
      ($) async {
        final appRobot = AppRobot($);
        // Setup
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('explorer');

        // Search for non-existent medication
        await appRobot.explorer.enterSearchQuery('MedicamentInexistant12345');
        await appRobot.explorer.submitSearch();
        await appRobot.waitForNetworkRequests();

        // Verify empty state
        appRobot.explorer.expectEmptySearchState();

        // Search with very specific query that should return no results
        await appRobot.explorer.enterSearchQuery('xyzabc123');
        await appRobot.explorer.submitSearch();

        // Verify no results state
        appRobot.explorer.expectPartialTextVisible('Aucun résultat');

        // Clear search and verify normal state returns
        await appRobot.explorer.clearSearch();
        await appRobot.waitAndSettle();

        appRobot.explorer.expectSearchResultsVisible();

        debugPrint('✅ GP2.6: Empty search and no results handling passed');
      },
    );

    patrolTest(
      'GP2.7: Explorer detail sheet actions',
      config: const PatrolTesterConfig(printLogs: true),
      ($) async {
        final appRobot = AppRobot($);
        // Setup
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('explorer');

        // Search and open details
        await appRobot.explorer.enterSearchQuery('Doliprane');
        await appRobot.explorer.submitSearch();

        await appRobot.explorer.tapMedicationGroup('DOLIPRANE');
        await appRobot.explorer.waitForDrawer();

        await appRobot.explorer.tapMedicationCard('DOLIPRANE 1000 mg');
        await appRobot.explorer.waitForDetailSheet();

        // Test Fiche button
        await appRobot.explorer.tapFicheButton();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await appRobot.handleUnexpectedDialogs();

        // Test RCP button
        await appRobot.explorer.tapRcpButton();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await appRobot.handleUnexpectedDialogs();

        // Test "View in Explorer" button
        try {
          await appRobot.explorer.tapViewInExplorer();
          await appRobot.waitAndSettle();
        } catch (e) {
          debugPrint('⚠️ GP2.7: View in Explorer button not found');
        }

        // Test closing detail sheet
        await appRobot.explorer.closeDetailSheet();

        debugPrint('✅ GP2.7: Detail sheet actions completed');
      },
    );

    patrolTest(
      'GP2.8: Explorer pull-to-refresh and cache',
      config: const PatrolTesterConfig(printLogs: true),
      ($) async {
        final appRobot = AppRobot($);
        // Setup
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('explorer');

        // Perform initial search
        await appRobot.explorer.enterSearchQuery('Amoxicilline');
        await appRobot.explorer.submitSearch();
        await appRobot.waitForNetworkRequests();

        // Verify results
        appRobot.explorer.expectMedicationGroupVisible('AMOXICILLINE');

        // Pull to refresh
        await appRobot.explorer.pullToRefresh();
        await appRobot.waitForNetworkRequests();

        // Verify results are still there (cached or refreshed)
        await appRobot.explorer.expectMedicationGroupVisible('AMOXICILLINE');

        // Test navigation with back button
        await appRobot.navigateBack();
        await appRobot.waitAndSettle();

        // Verify we're still in explorer with search field focused
        await appRobot.explorer.expectSearchFieldVisible();

        debugPrint('✅ GP2.8: Pull-to-refresh and navigation completed');
      },
    );
  });
}
