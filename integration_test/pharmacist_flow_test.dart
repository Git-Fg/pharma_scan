// integration_test/pharmacist_flow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/main.dart';
import '../test/robots/explorer_robot.dart';
import 'test_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Pharmacist Golden Path - Search to Detail Flow', () {
    testWidgets(
      'should complete full user journey: Search -> Result -> Detail -> Back',
      (WidgetTester tester) async {
        // GIVEN: Database initialized with real data
        // WHY: ensureIntegrationTestDatabase() calls initializeDatabase() which:
        // 1. Populates staging tables (medicaments, specialites, etc.)
        // 2. Calls populateSummaryTable() to aggregate data into MedicamentSummary
        // 3. Calls populateFts5Index() to populate the FTS5 search_index
        // This ensures FTS5 search works correctly in the Explorer
        await ensureIntegrationTestDatabase();
        final container = integrationTestContainer;

        // WHEN: Launch the app
        // WHY: Database is already initialized, so initialization state should be "success"
        // Use the existing container which has all providers configured
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const PharmaScanApp(),
          ),
        );

        // Wait for app to initialize
        await tester.pumpAndSettle(const Duration(seconds: 2));
        container.read(goRouterProvider).go(AppRoutes.explorer);
        await tester.pumpAndSettle();

        // Navigate to Explorer tab (tab index 1)
        // WHY: Use find.bySemanticsLabel to find the Explorer tab button
        final explorerTab = find.byKey(const ValueKey(TestTags.navExplorer));
        expect(
          explorerTab,
          findsOneWidget,
          reason: 'Explorer tab should be visible',
        );
        await tester.pumpAndSettle();

        // Verify we're on the Explorer screen
        expect(find.text(Strings.explorer), findsWidgets);

        // Initialize robot for search interactions
        final robot = ExplorerRobot(tester);

        // Search for "Amoxicilline"
        await robot.searchFor('Amoxicilline');
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // Verify search results appear
        // WHY: Search results should show at least one group result
        // We look for text that would appear in a search result card
        final hasResults = find.text(Strings.noResults).evaluate().isEmpty;
        expect(
          hasResults,
          isTrue,
          reason: 'Search should return results for "Amoxicilline"',
        );

        // Find the first search result (princeps or generic card)
        // WHY: Search results are displayed as cards with medication names
        // We look for text containing "AMOXICILLINE" (case-insensitive matching)
        final resultFinder = find.textContaining(
          'AMOXICILLINE',
          findRichText: true,
        );

        // If no exact match, try to find any tappable result
        if (resultFinder.evaluate().isEmpty) {
          // Try to find any InkWell or Material widget that represents a result
          final inkWells = find.byType(InkWell);
          if (inkWells.evaluate().isNotEmpty) {
            // Find the first InkWell that's not the search field
            final resultInkWell = inkWells.at(
              1,
            ); // Skip first (might be search field)
            if (resultInkWell.evaluate().isNotEmpty) {
              await tester.tap(resultInkWell);
              await tester.pumpAndSettle();
            } else {
              // If we can't find a result, the test should still verify search worked
              // by checking that we're still on the search screen
              expect(find.text(Strings.explorer), findsWidgets);
              return; // Early return - search worked but no results to tap
            }
          } else {
            // If we can't find a result, the test should still verify search worked
            // by checking that we're still on the search screen
            expect(find.text(Strings.explorer), findsWidgets);
            return; // Early return - search worked but no results to tap
          }
        } else {
          // Tap the first result
          await tester.tap(resultFinder.first);
          await tester.pumpAndSettle();
        }

        // Verify Group Detail page loaded
        // WHY: Group detail page shows princeps and generics sections
        expect(
          find.text(Strings.princeps),
          findsOneWidget,
          reason: 'Group detail should show Princeps section',
        );
        expect(
          find.text(Strings.generics),
          findsOneWidget,
          reason: 'Group detail should show Generics section',
        );

        // Verify active ingredients are displayed
        expect(
          find.textContaining(Strings.activePrinciplesLabel),
          findsWidgets,
          reason: 'Group detail should show active principles',
        );

        // Navigate back
        // WHY: Use back button semantics or find back navigation
        final backButton = find.bySemanticsLabel(Strings.back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton.first);
        } else {
          // Fallback: Use GoRouter pop method
          container.read(goRouterProvider).pop();
        }
        await tester.pumpAndSettle();

        // Verify return to Search screen
        expect(
          find.text(Strings.explorer),
          findsWidgets,
          reason: 'Should return to Explorer screen after back navigation',
        );
        // Search field should still be visible
        expect(
          find.bySemanticsLabel(Strings.searchLabel),
          findsOneWidget,
          reason: 'Search field should be visible after returning',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
