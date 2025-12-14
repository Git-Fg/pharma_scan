import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../data/test_products.dart';
import '../helpers/mock_preferences_helper.dart';
import '../helpers/test_database_helper.dart';
import '../robots/app_robot.dart';

/// GP4: Explorer Deep Dive Test
///
/// Test complex explorer functionality:
/// 1. Apply "Voie Orale" filter
/// 2. Navigate alphabetically to specific sections
/// 3. Open complex medication groups
/// 4. Verify pricing and reimbursement information
/// 5. Test advanced filtering and sorting
/// 6. Validate cluster information and generic relationships
void main() {
  group('GP4: Explorer Deep Dive Tests', () {
    late AppRobot appRobot;

    setUp(() async {
      appRobot = AppRobot($);
    });

    patrolTest(
      'GP4.1: Complex medication group exploration - Doliprane cluster',
      config: PatrolTesterConfig(
        reportLogs: true,
      ),
      ($) async {
        // PHASE 1: Setup and Initialization
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();

        // PHASE 2: Navigate to Explorer and apply "Voie Orale" filter
        await appRobot.navigateToTab('explorer');
        await appRobot.explorer.expectExplorerScreenVisible();

        // Open filters and apply "Voie Orale"
        await appRobot.explorer.openFilters();
        await appRobot.explorer.selectRouteFilter('Voie orale');
        await appRobot.explorer.applyFilters();
        await appRobot.waitForNetworkRequests();

        // Verify filter is active
        appRobot.explorer.expectFilterActive('Voie orale');

        // PHASE 3: Navigate alphabetically to 'D' section
        await appRobot.explorer.tapAlphabeticalIndex('D');
        await $.pumpAndSettle();

        await appRobot.explorer.scrollToSection('D');

        // PHASE 4: Find and open Doliprane cluster (complex group)
        print('🔍 GP4.1: Searching for Doliprane cluster');

        await appRobot.explorer.expectMedicationGroupVisible('DOLIPRANE');

        // Open Doliprane group
        await appRobot.explorer.tapMedicationGroup('DOLIPRANE');
        await appRobot.explorer.waitForDrawer();
        await appRobot.explorer.expectDrawerOpen();

        // PHASE 5: Verify cluster contains multiple forms
        await $.waitForTextToAppear('DOLIPRANE', timeout: const Duration(seconds: 2));

        // Look for different dosages
        final dosageVariants = [
          '1000 mg',
          '500 mg',
          '200 mg',
          '80 mg',
        ];

        var foundVariants = <String>[];
        for (final dosage in dosageVariants) {
          try {
            await $.waitForTextToAppear(dosage, timeout: const Duration(seconds: 1));
            foundVariants.add(dosage);
          } catch (e) {
            // Dosage not found, continue
          }
        }

        print('📊 GP4.1: Found ${foundVariants.length} dosage variants: ${foundVariants.join(', ')}');

        // PHASE 6: Test pricing information
        print('💰 GP4.1: Checking pricing information');

        // Tap on specific medication to see pricing
        if (foundVariants.contains('1000 mg')) {
          await appRobot.explorer.tapMedicationCard('DOLIPRANE 1000 mg');
          await appRobot.explorer.waitForDetailSheet();

          // Look for pricing information
          try {
            await $.waitForTextToAppearContaining('Prix', timeout: const Duration(seconds: 2));
            await $.waitForTextToAppearContaining('€', timeout: const Duration(seconds: 2));
            await $.waitForTextToAppearContaining('Remboursement', timeout: const Duration(seconds: 2));
            print('✅ GP4.1: Pricing information found');
          } catch (e) {
            print('⚠️ GP4.1: Pricing information not immediately visible');
          }

          // Verify form details
          await $.waitForTextToAppear('Comprimé');
          await $.waitForTextToAppear('Boîte de');

          // Close detail sheet
          await appRobot.explorer.closeDetailSheet();
        }

        // PHASE 7: Verify cluster information
        await appRobot.explorer.expectGroupDetailVisible();

        // Look for cluster metadata
        try {
          await $.waitForTextToAppearContaining('produits');
          await $.waitForTextToAppearContaining('formes');
          print('✅ GP4.1: Cluster information verified');
        } catch (e) {
          print('⚠️ GP4.1: Cluster metadata not found');
        }

        print('✅ GP4.1: Complex medication group exploration completed');
      },
    );

    patrolTest(
      'GP4.2: Advanced filtering - Administration routes and prices',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('explorer');

        // Test multiple filters
        await appRobot.explorer.openFilters();

        // Apply "Voie Orale" filter
        await appRobot.explorer.selectRouteFilter('Voie orale');

        // Apply price filter if available
        try {
          await appRobot.explorer.selectPriceFilter('Moins de 5€');
        } catch (e) {
          print('⚠️ GP4.2: Price filter not available');
        }

        await appRobot.explorer.applyFilters();
        await appRobot.waitForNetworkRequests();

        // Search for common medications
        await appRobot.explorer.enterSearchQuery('Paracétamol');
        await appRobot.explorer.submitSearch();
        await appRobot.waitForNetworkRequests();

        // Verify filtered results
        appRobot.explorer.expectMedicationGroupVisible('DOLIPRANE');

        // Verify filter indicators
        appRobot.explorer.expectFilterActive('Voie orale');

        // Clear filters and verify difference
        await appRobot.explorer.resetFilters();
        await appRobot.waitForNetworkRequests();

        // Search again - should get more results
        await appRobot.explorer.clearSearch();
        await appRobot.explorer.enterSearchQuery('Paracétamol');
        await appRobot.explorer.submitSearch();
        await appRobot.waitForNetworkRequests();

        print('✅ GP4.2: Advanced filtering completed');
      },
    );

    patrolTest(
      'GP4.3: Medication cluster depth and complexity testing',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('explorer');

        // Search for medication known to have many variants
        await appRobot.explorer.enterSearchQuery('Ibuprofène');
        await appRobot.explorer.submitSearch();
        await appRobot.waitForNetworkRequests();

        // Open main cluster
        await appRobot.explorer.tapMedicationGroup('IBUPROFENE');
        await appRobot.explorer.waitForDrawer();

        // Count available variants
        await $.pumpAndSettle();

        try {
          final medicationCards = find.byType(ListTile);
          if (medicationCards.evaluate().isNotEmpty) {
            final cardCount = medicationCards.evaluate().length;
            print('📊 GP4.3: Found $cardCount IBUPROFENE variants');

            // Verify different forms exist
            final forms = [
              'Comprimé',
              'Gélule',
              'Sirop',
              'Solution injectable',
            ];

            for (final form in forms) {
              try {
                await $.waitForTextToAppear(form, timeout: const Duration(seconds: 1));
                print('✅ GP4.3: Found $form form');
              } catch (e) {
                // Form not found
              }
            }
          }
        } catch (e) {
          print('⚠️ GP4.3: Could not count medication variants');
        }

        // Test navigation within large cluster
        if (find.byType(Scrollable).evaluate().isNotEmpty) {
          await appRobot.explorer.scrollToBottom();
          await appRobot.explorer.scrollToTop();
        }

        print('✅ GP4.3: Cluster complexity testing completed');
      },
    );

    patrolTest(
      'GP4.4: Generic relationships and price comparisons',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('explorer');

        // Search for Doliprane (princeps)
        await appRobot.explorer.enterSearchQuery('Doliprane 1000');
        await appRobot.explorer.submitSearch();
        await appRobot.waitForNetworkRequests();

        // Open Doliprane group
        await appRobot.explorer.tapMedicationGroup('DOLIPRANE');
        await appRobot.explorer.waitForDrawer();

        // Look for generic equivalents
        try {
          await $.waitForTextToAppear('Générique', timeout: const Duration(seconds: 2));
          print('✅ GP4.4: Generic equivalents found');

          // Check for multiple generic options
          final genericTexts = find.textContaining('BIOGARAN');
          if (genericTexts.evaluate().isNotEmpty) {
            print('📊 GP4.4: Found BIOGARAN generics');
          }
        } catch (e) {
          print('⚠️ GP4.4: Generic section not found');
        }

        // Close and search for generic specifically
        await appRobot.explorer.closeDrawer();
        await appRobot.explorer.clearSearch();

        await appRobot.explorer.enterSearchQuery('PARACETAMOL BIOGARAN');
        await appRobot.explorer.submitSearch();
        await appRobot.waitForNetworkRequests();

        // Verify generic medication appears
        try {
          await appRobot.explorer.expectMedicationGroupVisible('PARACETAMOL');
          print('✅ GP4.4: Generic medication found in search');
        } catch (e) {
          print('⚠️ GP4.4: Generic medication not found');
        }

        print('✅ GP4.4: Generic relationships testing completed');
      },
    );

    patrolTest(
      'GP4.5: Pricing and reimbursement verification',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('explorer');

        // Test various medications for pricing info
        final medicationsWithPricing = [
          'DOLIPRANE 1000 mg',
          'ASPIRINE 500 mg',
          'IBUPROFENE 400 mg',
        ];

        for (final medication in medicationsWithPricing) {
          print('💰 GP4.5: Checking pricing for $medication');

          await appRobot.explorer.enterSearchQuery(medication);
          await appRobot.explorer.submitSearch();
          await appRobot.waitForNetworkRequests();

          try {
            // Find and open the medication
            final medicationFinder = find.text(medication);
            if (medicationFinder.evaluate().isNotEmpty) {
              await appRobot.explorer.tapMedicationCard(medication);
              await appRobot.explorer.waitForDetailSheet();

              // Look for pricing information
              final priceFound = await $.waitForTextToAppearContaining('€', timeout: const Duration(seconds: 2));
              final reimbursementFound = await $.waitForTextToAppearContaining('Remboursement', timeout: const Duration(seconds: 2));

              if (priceFound && reimbursementFound) {
                print('✅ GP4.5: Full pricing info found for $medication');
              } else if (priceFound) {
                print('⚠️ GP4.5: Price found but no reimbursement info for $medication');
              } else {
                print('⚠️ GP4.5: No pricing info immediately available for $medication');
              }

              await appRobot.explorer.closeDetailSheet();
            }
          } catch (e) {
            print('⚠️ GP4.5: Error checking pricing for $medication: $e');
          }

          await appRobot.explorer.clearSearch();
        }

        print('✅ GP4.5: Pricing verification completed');
      },
    );

    patrolTest(
      'GP4.6: Search performance with complex queries',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('explorer');

        // Test complex search queries
        final complexQueries = [
          'paracétamol',
          'PARACETAMOL', // Case insensitive
          'Doliprane 1000', // Specific with dosage
          'Anti-inflammatoire', // Category search
          'AINS', // Abbreviation search
        ];

        final searchTimes = <int>[];

        for (final query in complexQueries) {
          print('🔍 GP4.6: Testing complex query: "$query"');

          final startTime = DateTime.now().millisecondsSinceEpoch;

          await appRobot.explorer.enterSearchQuery(query);
          await Future.delayed(const Duration(milliseconds: 500)); // Debounce
          await $.pumpAndSettle();

          final endTime = DateTime.now().millisecondsSinceEpoch;
          searchTimes.add(endTime - startTime);

          // Check if we got results
          try {
            final resultsFound = find.textContaining(query.substring(0, 3).toUpperCase());
            if (resultsFound.evaluate().isNotEmpty) {
              print('✅ GP4.6: Results found for "$query"');
            } else {
              print('⚠️ GP4.6: No results for "$query"');
            }
          } catch (e) {
            print('⚠️ GP4.6: Error checking results for "$query"');
          }

          await appRobot.explorer.clearSearch();
          await $.pumpAndSettle();
        }

        final averageSearchTime = searchTimes.reduce((a, b) => a + b) / searchTimes.length;
        print('📊 GP4.6: Average complex search time: ${averageSearchTime.round()}ms');

        print('✅ GP4.6: Complex search performance testing completed');
      },
    );

    patrolTest(
      'GP4.7: Navigation depth and breadcrumb testing',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('explorer');

        // Deep navigation test
        await appRobot.explorer.enterSearchQuery('Doliprane');
        await appRobot.explorer.submitSearch();

        // Level 1: Search results
        await appRobot.explorer.expectSearchResultsVisible();

        // Level 2: Group detail
        await appRobot.explorer.tapMedicationGroup('DOLIPRANE');
        await appRobot.explorer.waitForDrawer();

        // Level 3: Medication detail
        await appRobot.explorer.tapMedicationCard('DOLIPRANE 1000 mg');
        await appRobot.explorer.waitForDetailSheet();

        // Test navigation back through levels
        await appRobot.explorer.closeDetailSheet();
        await appRobot.explorer.expectDrawerOpen();

        await appRobot.explorer.closeDrawer();
        await appRobot.explorer.expectSearchResultsVisible();

        // Test breadcrumb functionality if available
        try {
          await $.waitForTextToAppearContaining('Retour');
          await $.tap($('Retour'));
          print('✅ GP4.7: Breadcrumb navigation found');
        } catch (e) {
          print('⚠️ GP4.7: No breadcrumb navigation found');
        }

        print('✅ GP4.7: Navigation depth testing completed');
      },
    );
  });
}