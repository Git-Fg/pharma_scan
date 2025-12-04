import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';

import 'test_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUpAll(() async {
    await ensureIntegrationTestDatabase();
    final container = integrationTestContainer;
    db = container.read(appDatabaseProvider);
  });

  group('Smoke Test - Installation & Initialization', () {
    testWidgets(
      'should populate MedicamentSummary table after initialization',
      (WidgetTester tester) async {
        final summaries = await (db.select(
          db.medicamentSummary,
        )..limit(10)).get();

        expect(
          summaries,
          isNotEmpty,
          reason: 'MedicamentSummary should be populated after initialization',
        );

        for (final summary in summaries) {
          expect(summary.cisCode, isNotEmpty);
          expect(summary.nomCanonique, isNotEmpty);
          expect(summary.isPrinceps, isA<bool>());
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      'should populate FTS5 search_index for full-text search',
      (WidgetTester tester) async {
        final searchResults = await db
            .customSelect('SELECT COUNT(*) as count FROM search_index')
            .getSingle();

        final count = searchResults.read<int>('count');

        expect(
          count,
          greaterThan(0),
          reason: 'FTS5 search_index should be populated after initialization',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
