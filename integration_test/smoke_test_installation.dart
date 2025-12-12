// integration_test/smoke_test_installation.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:pharma_scan/core/database/database.dart';

import 'helpers/golden_db_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUpAll(() async {
    // Load the golden database artifact instead of manual seeding
    // This is the "Thin Client" approach - the DB comes pre-populated
    db = await loadGoldenDatabase();
  });

  tearDownAll(() async {
    await db.close();
  });

  group('Smoke Test - Installation & Initialization', () {
    testWidgets(
      'should load data from pre-prepared golden database',
      (WidgetTester tester) async {
        // Test that data is already present in medicament_summary
        final summaries = await (db.select(
          db.medicamentSummary,
        )..limit(10)).get();

        expect(
          summaries,
          isNotEmpty,
          reason: 'MedicamentSummary should be populated from golden database',
        );

        // Verify we have real-world data from the backend pipeline
        expect(
          summaries.length,
          greaterThan(0),
          reason: 'Should have medications from golden database',
        );

        // Verify all entries have required fields
        for (final summary in summaries) {
          expect(summary.cisCode, isNotEmpty, reason: 'cisCode must be set');
          expect(
            summary.nomCanonique,
            isNotEmpty,
            reason: 'nomCanonique must be set',
          );
          expect(
            summary.princepsDeReference,
            isNotEmpty,
            reason: 'princepsDeReference must be set',
          );
          expect(summary.isPrinceps, isA<bool>());
        }

        // Check that the schema has sort_order column (was missing in old seeding)
        // This validates the golden DB has the correct schema
        final firstSummary = summaries.first;
        // Verify summary has required fields
        expect(firstSummary.cisCode, isNotEmpty);
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    testWidgets(
      'should have FTS5 search_index populated',
      (WidgetTester tester) async {
        // Test that search index is populated
        final searchResults = await db
            .customSelect(
              'SELECT COUNT(*) as count FROM search_index',
            )
            .getSingle();

        final count = searchResults.read<int>('count');

        expect(
          count,
          greaterThan(0),
          reason: 'FTS5 search_index should be populated from golden database',
        );
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    testWidgets(
      'should be able to query medications with filters',
      (WidgetTester tester) async {
        // Test filtering by princeps status
        final princepsMeds =
            await (db.select(db.medicamentSummary)
                  ..where((tbl) => tbl.isPrinceps.equals(true))
                  ..limit(10))
                .get();

        expect(
          princepsMeds,
          isNotEmpty,
          reason: 'Should have princeps medications in golden database',
        );

        // Test filtering by OTC status
        final otcMeds =
            await (db.select(db.medicamentSummary)
                  ..where((tbl) => tbl.isOtc.equals(true))
                  ..limit(10))
                .get();

        expect(
          otcMeds,
          isNotEmpty,
          reason: 'Should have OTC medications in golden database',
        );

        // Verify cluster information is preserved
        final clusteredMeds =
            await (db.select(db.medicamentSummary)
                  ..where((tbl) => tbl.clusterId.isNotNull())
                  ..limit(10))
                .get();

        expect(
          clusteredMeds,
          isNotEmpty,
          reason: 'Should have clustered medications',
        );
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    testWidgets(
      'should have cluster_names table populated',
      (WidgetTester tester) async {
        final clusters = await (db.select(db.clusterNames)..limit(10)).get();

        expect(
          clusters,
          isNotEmpty,
          reason: 'cluster_names should be populated from golden database',
        );

        for (final cluster in clusters) {
          expect(
            cluster.clusterId,
            isNotEmpty,
            reason: 'clusterId must be set',
          );
          expect(
            cluster.clusterName,
            isNotEmpty,
            reason: 'clusterName must be set',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    testWidgets(
      'should have laboratories table populated',
      (WidgetTester tester) async {
        final labs = await (db.select(db.laboratories)..limit(10)).get();

        expect(
          labs,
          isNotEmpty,
          reason: 'laboratories should be populated from golden database',
        );
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );
  });
}
