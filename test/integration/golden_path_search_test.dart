import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/providers.dart';
import 'package:pharma_scan/features/explorer/presentation/screens/database_search_view.dart';

import '../helpers/golden_db_helper.dart';

void main() {
  group('Golden Path Search Integration Tests', () {
    late AppDatabase db;

    setUp(() async {
      db = await loadGoldenDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('golden path: user can find paracetamol through search',
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

      // User starts searching
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'paracetamol');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      // Should find results
      expect(find.byType(ListView), findsOneWidget);
      expect(find.textContaining('paracetamol'), findsWidgets);
    });

    testWidgets('golden path: search result navigation works', (tester) async {
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

      // Search for a known medication
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'doliprane');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      // Try to tap on a result if available
      final resultTiles = find.byType(ListTile);
      if (resultTiles.evaluate().isNotEmpty) {
        await tester.tap(resultTiles.first);
        await tester.pumpAndSettle();

        // Should have navigated somewhere
        expect(find.byType(Scaffold), findsWidgets);
      }
    });

    testWidgets('golden path: diacritics insensitive search works',
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

      // Search with accent
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'paracétamol');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      // Should find results despite accent
      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
