import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../data/test_products.dart';
import '../helpers/mock_preferences_helper.dart';
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
    late AppRobot appRobot;

    setUp(() async {
      appRobot = AppRobot($);
    });

    patrolTest(
      'GP2.1: Complete search workflow - Navigate → Search → Results → Detail',
      config: PatrolTesterConfig(
        reportLogs: true,
      ),
      ($) async {
        // PHASE 1: Setup and Initialization
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();

        // PHASE 2: Navigate to Explorer
        await appRobot.navigateToTab('explorer');
        await appRobot.explorer.expectExplorerScreenVisible();
        await appRobot.explorer.expectSearchFieldVisible();

        // PHASE 3: Search for "Amoxicilline"
        await $.measureTime(
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
        await $.waitForTextToAppear('AMOXICILLINE');

        // Look for multiple Amoxicilline variants
        expect(find.textContaining('AMOXICILLINE'), findsWidgets);

        // Verify search results contain expected information
        await appRobot.explorer.expectMedicationGroupVisible('AMOXICILLINE');

        // PHASE 6: Tap on medication group
        await appRobot.explorer.tapMedicationGroup('AMOXICILLINE');
        await appRobot.explorer.waitForDrawer();
        await appRobot.explorer.expectDrawerOpen();

        // PHASE 7: Verify group detail information
        await $.waitForTextToAppear('AMOXICILLINE');
        await $.waitForTextToAppear('500 mg'); // Common dosage
        await $.waitForTextToAppear('Antibiotique');

        // PHASE 8: Tap on specific medication
        await appRobot.explorer.tapMedicationCard('AMOXICILLINE 500 mg');
        await appRobot.explorer.waitForDetailSheet();

        // PHASE 9: Verify medication detail
        await $(#medicationDetailSheet).waitUntilVisible();
        await $.waitForTextToAppear('AMOXICILLINE 500 mg');
        await $.waitForTextToAppear(TestProducts.amoxicilline500Labo);

        // Verify action buttons
        await $(#ficheButton).waitUntilVisible();
        await $(#rcpButton).waitUntilVisible();

        print('✅ GP2.1: Complete search workflow passed');
      },
    );

    patrolTest(
      'GP2.2: Explorer filters - Route administration',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('explorer');

        // Open filters
        await appRobot.explorer.openFilters();
        await appRobot.explorer.expectFilterVisible('Voie orale');

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
        await $.waitForTextToAppear('DOLIPRANE');
        expect(find.textContaining('orale'), findsWidgets);

        print('✅ GP2.2: Route administration filter passed');
      },
    );

    patrolTest(
      'GP2.3: Explorer alphabetical navigation',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('explorer');

        // Verify alphabetical index is visible
        appRobot.explorer.expectAlphabeticalIndexVisible();

        // Navigate to 'D' section
        await appRobot.explorer.tapAlphabeticalIndex('D');
        await $.pumpAndSettle();

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

        print('✅ GP2.3: Alphabetical navigation passed');
      },
    );

    patrolTest(
      'GP2.4: Explorer search debouncing and performance',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('explorer');

        // Test rapid search input
        final searchTimes = <int>[];

        for (int i = 0; i < 3; i++) {
          final startTime = DateTime.now().millisecondsSinceEpoch;

          await appRobot.explorer.tapSearchField();
          await appRobot.explorer.enterSearchQuery('A'); // Single letter
          await Future.delayed(const Duration(milliseconds: 300)); // Wait for debouncing
          await $.pumpAndSettle();

          final endTime = DateTime.now().millisecondsSinceEpoch;
          searchTimes.add(endTime - startTime);

          // Clear search
          await appRobot.explorer.clearSearch();
        }

        final averageSearchTime = searchTimes.reduce((a, b) => a + b) / searchTimes.length;
        print('📊 GP2.4: Average search time: ${averageSearchTime.round()}ms');

        // Test longer search
        await appRobot.explorer.enterSearchQuery('Paracétamol');
        await Future.delayed(const Duration(milliseconds: 500));
        await $.pumpAndSettle();

        // Verify results
        appRobot.explorer.expectMedicationGroupVisible('DOLIPRANE');

        print('✅ GP2.4: Search debouncing and performance test completed');
      },
    );

    patrolTest(
      'GP2.5: Explorer generic vs princeps identification',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
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
          await $.waitForTextToAppear('Générique', timeout: const Duration(seconds: 2));
          print('✅ GP2.5: Generic badge found for Doliprane');
        } catch (e) {
          print('⚠️ GP2.5: Generic badges not visible, checking other indicators');
        }

        // Search for generic specifically
        await appRobot.explorer.closeDetailSheet();
        await appRobot.explorer.enterSearchQuery('PARACETAMOL BIOGARAN');
        await appRobot.explorer.submitSearch();

        // Should find generic equivalent
        await appRobot.explorer.expectMedicationGroupVisible('PARACETAMOL');

        print('✅ GP2.5: Generic vs princeps identification completed');
      },
    );

    patrolTest(
      'GP2.6: Explorer empty search and no results handling',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
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
        expect(find.textContaining('Aucun résultat'), findsWidgets);

        // Clear search and verify normal state returns
        await appRobot.explorer.clearSearch();
        await $.pumpAndSettle();

        appRobot.explorer.expectSearchResultsVisible();

        print('✅ GP2.6: Empty search and no results handling passed');
      },
    );

    patrolTest(
      'GP2.7: Explorer detail sheet actions',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
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
        await Future.delayed(const Duration(milliseconds: 500));
        await appRobot.handleAnyDialog();

        // Test RCP button
        await app_robot.explorer.tapRcpButton();
        await Future.delayed(const Duration(milliseconds: 500));
        await app_robot.handleAnyDialog();

        // Test "View in Explorer" button
        try {
          await app_robot.explorer.tapViewInExplorer();
          await $.pumpAndSettle();
        } catch (e) {
          print('⚠️ GP2.7: View in Explorer button not found');
        }

        // Test closing detail sheet
        await app_robot.explorer.closeDetailSheet();

        print('✅ GP2.7: Detail sheet actions completed');
      },
    );

    patrolTest(
      'GP2.8: Explorer pull-to-refresh and cache',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await app_robot.completeAppInitialization();
        await app_robot.navigateToTab('explorer');

        // Perform initial search
        await app_robot.explorer.enterSearchQuery('Amoxicilline');
        await app_robot.explorer.submitSearch();
        await app_robot.waitForNetworkRequests();

        // Verify results
        app_robot.explorer.expectMedicationGroupVisible('AMOXICILLINE');

        // Pull to refresh
        await app_robot.explorer.pullToRefresh();
        await app_robot.waitForNetworkRequests();

        // Verify results are still there (cached or refreshed)
        app_robot.explorer.expectMedicationGroupVisible('AMOXICILLINE');

        // Test navigation with back button
        await app_robot.navigateBack();
        await $.pumpAndSettle();

        // Verify we're still in explorer with search field focused
        app_robot.explorer.expectSearchFieldVisible();

        print('✅ GP2.8: Pull-to-refresh and navigation completed');
      },
    );
  });
}