import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';

import 'test_bootstrap.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late CatalogDao scanDao;
  late AppDatabase db;

  setUpAll(() async {
    await ensureIntegrationTestDatabase();
    final container = integrationTestContainer;
    db = container.read(appDatabaseProvider);
    scanDao = db.catalogDao;
  });

  group('Data Pipeline - SQL Aggregation & ScanResult Type Mapping', () {
    testWidgets(
      'should populate MedicamentSummary table with aggregated data',
      (WidgetTester tester) async {
        // GIVEN: Database initialized with real data
        // WHEN: Query MedicamentSummary table directly
        final summaries = await (db.select(
          db.medicamentSummary,
        )..limit(10)).get();

        // THEN: Verify MedicamentSummary contains aggregated data
        expect(
          summaries,
          isNotEmpty,
          reason: 'MedicamentSummary should be populated after initialization',
        );

        // Verify structure of summary records
        for (final summary in summaries) {
          expect(summary.cisCode, isNotEmpty);
          expect(summary.nomCanonique, isNotEmpty);
          // groupId can be null for standalone medications
          // isPrinceps should be a boolean
          expect(summary.isPrinceps, isA<bool>());
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      'should populate FTS5 search_index for full-text search',
      (WidgetTester tester) async {
        // GIVEN: Database initialized with real data
        // WHEN: Query search_index table directly
        final searchResults = await db
            .customSelect('SELECT COUNT(*) as count FROM search_index')
            .getSingle();

        final count = searchResults.read<int>('count');

        // THEN: Verify search_index is populated
        expect(
          count,
          greaterThan(0),
          reason: 'FTS5 search_index should be populated after initialization',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
    testWidgets(
      'should expose FTS5-backed search results via CatalogDao.searchMedicaments',
      (WidgetTester tester) async {
        // GIVEN: Database initialized with real data and populated FTS index
        // WHEN: We perform a search via CatalogDao using a common active principle
        final candidates = await scanDao.searchMedicaments('PARACETAMOL');

        // THEN: We should get at least one candidate and all should have canonical names
        expect(
          candidates,
          isNotEmpty,
          reason:
              'searchMedicaments should surface at least one candidate for PARACETAMOL.',
        );
        for (final candidate in candidates) {
          expect(candidate.nomCanonique, isNotEmpty);
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
    testWidgets(
      'should populate ATC codes in Specialites table',
      (WidgetTester tester) async {
        // GIVEN: Database initialized with real data
        // WHEN: Query specialites with ATC codes
        final specialitesWithAtc = await db
            .customSelect(
              'SELECT cis_code, atc_code FROM specialites WHERE atc_code IS NOT NULL LIMIT 10',
            )
            .get();

        // THEN: Verify some specialites have ATC codes
        expect(
          specialitesWithAtc,
          isNotEmpty,
          reason: 'Some specialites should have ATC codes',
        );

        for (final row in specialitesWithAtc) {
          expect(row.read<String>('cis_code'), isNotEmpty);
          expect(row.read<String>('atc_code'), isNotEmpty);
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
    testWidgets(
      'should return GenericScanResult for a generic medicament',
      (WidgetTester tester) async {
        // GIVEN: Database initialized with real data
        // WHEN: Find a generic medicament and get its scan result
        final generiquesResult = await db
            .customSelect(
              'SELECT gm.code_cip FROM group_members gm WHERE gm.type IN (1, 2, 4) LIMIT 1',
            )
            .getSingleOrNull();

        expect(
          generiquesResult,
          isNotNull,
          reason: 'Expected at least one generic medicament in group_members.',
        );

        final codeCipGenerique = generiquesResult!.read<String>('code_cip');
        final result = await scanDao.getProductByCip(codeCipGenerique);

        // THEN: Verify it returns a summary with groupId (generic)
        expect(result, isNotNull);
        expect(result!.cip, codeCipGenerique);
        expect(result.summary.nomCanonique, isNotEmpty);
        expect(
          result.summary.groupId,
          isNotNull,
          reason: 'Generic should have groupId',
        );
        expect(
          result.summary.isPrinceps,
          isFalse,
          reason: 'Generic should not be princeps',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      'should return PrincepsScanResult for a princeps medicament',
      (WidgetTester tester) async {
        // GIVEN: Database initialized with real data
        // WHEN: Find a princeps medicament and get its scan result
        final princepsResult = await db
            .customSelect(
              'SELECT gm.code_cip FROM group_members gm WHERE gm.type = 0 LIMIT 1',
            )
            .getSingleOrNull();

        expect(
          princepsResult,
          isNotNull,
          reason: 'Expected at least one princeps medicament in group_members.',
        );

        final codeCipPrinceps = princepsResult!.read<String>('code_cip');
        final result = await scanDao.getProductByCip(codeCipPrinceps);

        // THEN: Verify it returns a summary with isPrinceps = true
        expect(result, isNotNull);
        expect(result!.cip, codeCipPrinceps);
        expect(result.summary.nomCanonique, isNotEmpty);
        expect(
          result.summary.groupId,
          isNotNull,
          reason: 'Princeps should have groupId',
        );
        expect(result.summary.isPrinceps, isTrue, reason: 'Should be princeps');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      'should return StandaloneScanResult for a medicament with no group membership',
      (WidgetTester tester) async {
        // GIVEN: Database initialized with real data
        // WHEN: Find a medicament without group membership and get its scan result
        final nonGroupedResult = await db
            .customSelect(
              'SELECT m.code_cip FROM medicaments m LEFT JOIN group_members gm ON m.code_cip = gm.code_cip WHERE gm.code_cip IS NULL LIMIT 1',
            )
            .getSingleOrNull();

        expect(
          nonGroupedResult,
          isNotNull,
          reason: 'Expected at least one standalone medicament in medicaments.',
        );

        final codeCipStandalone = nonGroupedResult!.read<String>('code_cip');
        final result = await scanDao.getProductByCip(codeCipStandalone);

        // THEN: Verify it returns a summary without groupId (standalone)
        expect(
          result,
          isNotNull,
          reason: 'Standalone medicament should be found: $codeCipStandalone',
        );
        expect(result!.cip, codeCipStandalone);
        expect(result.summary.nomCanonique, isNotEmpty);
        expect(
          result.summary.groupId,
          isNull,
          reason: 'Standalone should not have groupId',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
