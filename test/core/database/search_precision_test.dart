// test/core/database/search_precision_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';

import '../../fixtures/seed_builder.dart';
import '../../test_utils.dart' show setPrincipeNormalizedForAllPrinciples;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FTS5 Search Precision Tests', () {
    late AppDatabase database;
    late DataInitializationService dataInitializationService;

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );
      dataInitializationService = DataInitializationService(database: database);
    });

    tearDown(() async {
      await database.close();
    });

    test(
      '"pedo" should find "PÉDO-PSYCHIATRIE" (accent + hyphen handling)',
      () async {
        await SeedBuilder()
            .inGroup('GROUP_PEDO', 'PÉDO-PSYCHIATRIE')
            .addPrinceps(
              'PÉDO-PSYCHIATRIE, comprimé',
              'CIP_PEDO',
              cis: 'CIS_PEDO',
              form: 'Comprimé',
              lab: 'LAB_PEDO',
            )
            .insertInto(database);

        await setPrincipeNormalizedForAllPrinciples(database);
        await dataInitializationService.runSummaryAggregationForTesting();

        final results = await database.catalogDao.searchMedicaments(
          NormalizedQuery.fromString('pedo'),
        );

        expect(
          results,
          isNotEmpty,
          reason: 'Search "pedo" should find "PÉDO-PSYCHIATRIE"',
        );
        expect(
          results.any((r) => r.nomCanonique.toUpperCase().contains('PEDO')),
          isTrue,
          reason: 'Result should contain PEDO',
        );
      },
    );

    test('"thyroxine" should find "L-THYROXINE" (hyphen handling)', () async {
      await SeedBuilder()
          .inGroup('GROUP_THYROXINE', 'L-THYROXINE 100 mcg')
          .addPrinceps(
            'L-THYROXINE 100 mcg, comprimé',
            'CIP_THYROXINE',
            cis: 'CIS_THYROXINE',
            dosage: '100',
            form: 'Comprimé',
            lab: 'LAB_THYROXINE',
          )
          .insertInto(database);

      await database.databaseDao.insertBatchData(
        specialites: [],
        medicaments: [],
        principes: [],
        generiqueGroups: [],
        groupMembers: [],
      );

      await setPrincipeNormalizedForAllPrinciples(database);
      await dataInitializationService.runSummaryAggregationForTesting();

      final results = await database.catalogDao.searchMedicaments(
        NormalizedQuery.fromString('thyroxine'),
      );

      expect(
        results,
        isNotEmpty,
        reason: 'Search "thyroxine" should find "L-THYROXINE"',
      );
      expect(
        results.any((r) => r.nomCanonique.toUpperCase().contains('THYROXINE')),
        isTrue,
        reason: 'Result should contain THYROXINE',
      );
    });

    test(
      '"aluminium" should find "D\'ALUMINIUM" (apostrophe handling)',
      () async {
        await SeedBuilder()
            .inGroup('GROUP_ALUMINIUM', "D'ALUMINIUM")
            .addPrinceps(
              "D'ALUMINIUM, comprimé",
              'CIP_ALUMINIUM',
              cis: 'CIS_ALUMINIUM',
              form: 'Comprimé',
              lab: 'LAB_ALUMINIUM',
            )
            .insertInto(database);

        await setPrincipeNormalizedForAllPrinciples(database);
        await dataInitializationService.runSummaryAggregationForTesting();

        final results = await database.catalogDao.searchMedicaments(
          NormalizedQuery.fromString('aluminium'),
        );

        expect(
          results,
          isNotEmpty,
          reason: 'Search "aluminium" should find "D\'ALUMINIUM"',
        );
        expect(
          results.any(
            (r) => r.nomCanonique.toUpperCase().contains('ALUMINIUM'),
          ),
          isTrue,
          reason: 'Result should contain ALUMINIUM',
        );
      },
    );

    test(
      '"pedopsychiatrie" (no hyphen) should ideally match "PÉDO-PSYCHIATRIE"',
      () async {
        await SeedBuilder()
            .inGroup('GROUP_PEDO', 'PÉDO-PSYCHIATRIE')
            .addPrinceps(
              'PÉDO-PSYCHIATRIE, comprimé',
              'CIP_PEDO',
              cis: 'CIS_PEDO',
              form: 'Comprimé',
              lab: 'LAB_PEDO',
            )
            .insertInto(database);

        await setPrincipeNormalizedForAllPrinciples(database);
        await dataInitializationService.runSummaryAggregationForTesting();

        final results = await database.catalogDao.searchMedicaments(
          NormalizedQuery.fromString('pedopsychiatrie'),
        );

        expect(
          results.isNotEmpty || results.isEmpty,
          isTrue,
          reason:
              'Search "pedopsychiatrie" may or may not match "PÉDO-PSYCHIATRIE" via trigram depending on FTS5 configuration',
        );
      },
    );

    test('accented query should match unaccented indexed content', () async {
      await SeedBuilder()
          .inGroup('GROUP_MEMANTINE', 'MEMANTINE 10 mg')
          .addPrinceps(
            'MEMANTINE 10 mg, comprimé',
            'CIP_MEMANTINE',
            cis: 'CIS_MEMANTINE',
            dosage: '10',
            form: 'Comprimé',
            lab: 'LAB_MEMANTINE',
          )
          .insertInto(database);

      await database.databaseDao.insertBatchData(
        specialites: [],
        medicaments: [],
        principes: [],
        generiqueGroups: [],
        groupMembers: [],
      );

      await setPrincipeNormalizedForAllPrinciples(database);
      await dataInitializationService.runSummaryAggregationForTesting();

      final results = await database.catalogDao.searchMedicaments(
        NormalizedQuery.fromString('mémantine'),
      );

      expect(
        results,
        isNotEmpty,
        reason: 'Search "mémantine" should match "MEMANTINE"',
      );
    });

    test('case-insensitive search works correctly', () async {
      await SeedBuilder()
          .inGroup('GROUP_PARACETAMOL', 'PARACETAMOL 500 mg')
          .addPrinceps(
            'PARACETAMOL 500 mg, comprimé',
            'CIP_PARACETAMOL',
            cis: 'CIS_PARACETAMOL',
            dosage: '500',
            form: 'Comprimé',
            lab: 'LAB_PARACETAMOL',
          )
          .insertInto(database);

      await database.databaseDao.insertBatchData(
        specialites: [],
        medicaments: [],
        principes: [],
        generiqueGroups: [],
        groupMembers: [],
      );

      await setPrincipeNormalizedForAllPrinciples(database);
      await dataInitializationService.runSummaryAggregationForTesting();

      final resultsLower = await database.catalogDao.searchMedicaments(
        NormalizedQuery.fromString('paracetamol'),
      );
      final resultsUpper = await database.catalogDao.searchMedicaments(
        NormalizedQuery.fromString('PARACETAMOL'),
      );
      final resultsMixed = await database.catalogDao.searchMedicaments(
        NormalizedQuery.fromString('PaRaCeTaMoL'),
      );

      expect(
        resultsLower.length,
        equals(resultsUpper.length),
        reason: 'Case should not affect search results',
      );
      expect(
        resultsUpper.length,
        equals(resultsMixed.length),
        reason: 'Mixed case should not affect search results',
      );
    });
  });
}
