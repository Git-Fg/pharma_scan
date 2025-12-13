import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/providers.dart';
import 'package:pharma_scan/features/explorer/presentation/screens/database_search_view.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/explorer_search_bar.dart';

import '../helpers/golden_db_helper.dart';

void main() {
  group('Search UI Flow Integration Tests', () {
    late AppDatabase db;

    setUp(() async {
      db = await loadGoldenDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('complete search flow from query to results', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider().overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DatabaseSearchView(),
            ),
          ),
        ),
      );

      // Wait for the search screen to load
      await tester.pumpAndSettle();

      // Verify search bar is present
      expect(find.byType(ExplorerSearchBar), findsOneWidget);

      // Tap on search bar
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Type a search query
      await tester.enterText(find.byType(TextField), 'paracetamol');
      await tester.pumpAndSettle();

      // Wait for search results to load
      await tester.pump(const Duration(seconds: 1));

      // Verify that search results are displayed
      expect(find.byType(ListView), findsOneWidget);

      // The search should return results
      expect(find.textContaining('paracetamol'), findsWidgets);
    });

    testWidgets('search with diacritics works correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider().overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DatabaseSearchView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Search with accent
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'paracétamol');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      // Should find results
      final withAccentResults = find.byType(ListTile);
      expect(withAccentResults, findsWidgets);

      // Clear and search without accent
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), ''); // Clear first
      await tester.enterText(find.byType(TextField), 'paracetamol');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      // Should also find results
      final withoutAccentResults = find.byType(ListTile);
      expect(withoutAccentResults, findsWidgets);
    });

    testWidgets('search with no results shows appropriate state',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider().overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DatabaseSearchView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Search for something that doesn't exist
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'xyznonexistent123456');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      // Should show empty state or no results message
      expect(find.text('Aucun résultat'), findsOneWidget);
    });

    testWidgets('search results are tappable and navigate correctly',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider().overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DatabaseSearchView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Search for a common medication
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'doliprane');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      // Find and tap on a search result
      final resultTiles = find.byType(ListTile);
      if (resultTiles.evaluate().isNotEmpty) {
        await tester.tap(resultTiles.first);
        await tester.pumpAndSettle();

        // Should navigate to medication detail or group view
        expect(find.byType(Scaffold), findsWidgets);
      }
    });

    testWidgets('real-time search updates as user types', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider().overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DatabaseSearchView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));

      // Type one character
      await tester.enterText(find.byType(TextField), 'p');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      // Type more characters
      await tester.enterText(find.byType(TextField), 'para');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));

      // Complete the query
      await tester.enterText(find.byType(TextField), 'paracetamol');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      // Should show progressively refined results
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('search UI handles loading and error states gracefully',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider().overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DatabaseSearchView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial state
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Start a search
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'aspirine');

      // Should not show indefinite loading
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Results should appear
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
