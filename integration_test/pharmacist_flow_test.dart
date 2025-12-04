// integration_test/pharmacist_flow_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/medicament_tile.dart';
import 'package:pharma_scan/main.dart';
import '../test/robots/explorer_robot.dart';
import 'test_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Pharmacist Golden Path - Search to Detail Flow', () {
    testWidgets(
      'should complete full user journey: Search -> Result -> Detail -> Back',
      (WidgetTester tester) async {
        await ensureIntegrationTestDatabase();
        final container = integrationTestContainer;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const PharmaScanApp(),
          ),
        );

        // Wait for app to initialize
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        final explorerTab = find.byKey(const ValueKey(TestTags.navExplorer));
        expect(
          explorerTab,
          findsOneWidget,
          reason: 'Explorer tab should be visible',
        );
        await tester.tap(explorerTab);
        await tester.pumpAndSettle();

        // Verify we're on the Explorer screen
        expect(find.text(Strings.explorer), findsWidgets);

        // Initialize robot for search interactions
        final robot = ExplorerRobot(tester);

        // Search for a very common molecule present in BDPM (paracetamol)
        await robot.searchFor('Paracetamol');
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        final resultTiles = find.byType(MedicamentTile);
        expect(
          resultTiles,
          findsWidgets,
          reason: 'Expected at least one search result for Paracetamol.',
        );

        await tester.tap(resultTiles.first);
        await tester.pumpAndSettle();

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

        final backButton = find.bySemanticsLabel(Strings.back);
        if (backButton.evaluate().isNotEmpty) {
          await tester.tap(backButton.first);
        } else {
          // Fallback: Navigation handled by AutoRoute
          // Pop is handled automatically by the router
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

    testWidgets(
      'Scenario B: Néfopam search should NOT group with Adriblastine (critical edge case)',
      (WidgetTester tester) async {
        await ensureIntegrationTestDatabase();
        final container = integrationTestContainer;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const PharmaScanApp(),
          ),
        );

        // Wait for app to initialize
        await tester.pumpAndSettle(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        final explorerTab = find.byKey(const ValueKey(TestTags.navExplorer));
        expect(explorerTab, findsOneWidget);
        await tester.tap(explorerTab);
        await tester.pumpAndSettle();

        // Verify we're on the Explorer screen
        expect(find.text(Strings.explorer), findsWidgets);

        // Initialize robot for search interactions
        final robot = ExplorerRobot(tester);

        // Search for "Néfopam" (known edge case from DOMAIN_LOGIC.md)
        // Note: This test verifies that Néfopam and Adriblastine are not incorrectly grouped.
        // If Néfopam is not in the database, the test will skip the grouping verification
        // but will still verify the search functionality works.
        await robot.searchFor('Néfopam');
        // Wait longer for search results to load (FTS5 search can take time)
        await tester.pumpAndSettle(const Duration(seconds: 2));

        final resultTiles = find.byType(MedicamentTile);
        final noResults = find.text(Strings.noResults);

        // Check if we have results or a "no results" message
        var hasResults = resultTiles.evaluate().isNotEmpty;
        var hasNoResultsMessage = noResults.evaluate().isNotEmpty;

        if (!hasResults && !hasNoResultsMessage) {
          // Wait a bit more in case results are still loading
          await tester.pumpAndSettle(const Duration(seconds: 1));
          // Re-evaluate after waiting
          hasResults = resultTiles.evaluate().isNotEmpty;
          hasNoResultsMessage = noResults.evaluate().isNotEmpty;
        }

        // CRITICAL: If no results found, the test MUST fail to prevent silent breakage.
        // This ensures search functionality is properly tested and database seeding is correct.
        expect(
          hasResults,
          isTrue,
          reason: 'Search for Néfopam MUST return results. Check DB seeding.',
        );

        expect(
          resultTiles,
          findsWidgets,
          reason: 'Expected search results for Néfopam',
        );

        // CRITICAL: Verify that Adriblastine is NOT in the results
        // This tests the "Suspicious Data" check that prevents incorrect grouping
        // Check all text on screen for Adriblastine using find.textContaining
        final adriblastineText = find.textContaining(
          'ADRIBLASTINE',
          findRichText: true,
        );
        expect(
          adriblastineText,
          findsNothing,
          reason:
              'CRITICAL: Adriblastine should NOT appear in Néfopam search results. '
              'This verifies the grouping logic correctly isolates these medications.',
        );
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    // Note: Scenario C (offline mode) would require a connectivity provider
    // which may not exist in the codebase. This test is deferred until
    // connectivity management is implemented.
  });
}
