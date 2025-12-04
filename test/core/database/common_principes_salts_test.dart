import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';

import '../../fixtures/seed_builder.dart';
import '../../test_utils.dart' show setPrincipeNormalizedForAllPrinciples;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MedicamentSummary.commonPrincipes salt cleanup', () {
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

    test('ROPINIROLE summaries have clean common principles', () async {
      await SeedBuilder()
          .inGroup('GROUP_ROPINIROLE', 'ROPINIROLE 1 mg')
          .addPrinceps(
            'REQUIP 1 mg, comprimé',
            'CIP_ROPINIROLE',
            cis: 'CIS_ROPINIROLE',
            dosage: '1',
            form: 'Comprimé',
            lab: 'GSK',
          )
          .insertInto(database);

      await database.databaseDao.insertBatchData(
        specialites: [],
        medicaments: [],
        principes: [
          {
            'code_cip': 'CIP_ROPINIROLE',
            'principe': 'ROPINIROLE (CHLORHYDRATE DE)',
            'dosage': '1',
            'dosage_unit': 'mg',
          },
        ],
        generiqueGroups: [],
        groupMembers: [],
      );

      await setPrincipeNormalizedForAllPrinciples(database);
      await dataInitializationService.runSummaryAggregationForTesting();

      final rows = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_ROPINIROLE'))).get();

      expect(rows, isNotEmpty);

      for (final row in rows) {
        final principles = row.principesActifsCommuns;
        expect(
          principles,
          isNotEmpty,
          reason: 'ROPINIROLE should expose at least one active principle',
        );
        expect(
          principles.any(
            (p) => p.contains('CHLORHYDRATE'),
          ),
          isFalse,
        );
        expect(
          principles.any(
            (p) => p == 'ROPINIROLE',
          ),
          isTrue,
        );
      }
    });

    test('MÉMANTINE summaries have clean common principles', () async {
      await SeedBuilder()
          .inGroup('GROUP_MEMANTINE', 'MEMANTINE 10 mg')
          .addPrinceps(
            'AXURA 10 mg, comprimé',
            'CIP_MEMANTINE',
            cis: 'CIS_MEMANTINE',
            dosage: '10',
            form: 'Comprimé',
            lab: 'LUNDBECK',
          )
          .insertInto(database);

      await database.databaseDao.insertBatchData(
        specialites: [],
        medicaments: [],
        principes: [
          {
            'code_cip': 'CIP_MEMANTINE',
            'principe': 'MÉMANTINE (CHLORHYDRATE DE)',
            'dosage': '10',
            'dosage_unit': 'mg',
          },
        ],
        generiqueGroups: [],
        groupMembers: [],
      );

      await setPrincipeNormalizedForAllPrinciples(database);
      await dataInitializationService.runSummaryAggregationForTesting();

      final rows = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_MEMANTINE'))).get();

      expect(rows, isNotEmpty);

      for (final row in rows) {
        final principles = row.principesActifsCommuns;
        expect(
          principles.any(
            (p) => p.contains('CHLORHYDRATE'),
          ),
          isFalse,
        );
        expect(
          principles.any(
            (p) => p == 'MEMANTINE' || p == 'MÉMANTINE' || p == 'MEMENTINE',
          ),
          isTrue,
        );
      }
    });

    test('INDAPAMIDE, PÉRINDOPRIL summaries drop ERBUMINE', () async {
      await SeedBuilder()
          .inGroup('GROUP_COMBINATION', 'INDAPAMIDE + PERINDOPRIL')
          .addPrinceps(
            'COVERSYL PLUS 1.25 mg/2.5 mg, comprimé',
            'CIP_COMBO',
            cis: 'CIS_COMBO',
            dosage: '1.25',
            form: 'Comprimé',
            lab: 'SERVIER',
          )
          .insertInto(database);

      await database.databaseDao.insertBatchData(
        specialites: [],
        medicaments: [],
        principes: [
          {
            'code_cip': 'CIP_COMBO',
            'principe': 'INDAPAMIDE',
            'dosage': '1.25',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_COMBO',
            'principe': 'PÉRINDOPRIL (ERBUMINE)',
            'dosage': '2.5',
            'dosage_unit': 'mg',
          },
        ],
        generiqueGroups: [],
        groupMembers: [],
      );

      await setPrincipeNormalizedForAllPrinciples(database);
      await dataInitializationService.runSummaryAggregationForTesting();

      final rows = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_COMBO'))).get();

      expect(rows, isNotEmpty);

      for (final row in rows) {
        final principles = row.principesActifsCommuns;
        expect(
          principles.any((p) => p.contains('INDAPAMIDE')),
          isTrue,
        );
        expect(
          principles.any((p) => p.startsWith('PERINDOPRIL')),
          isTrue,
        );
        expect(
          principles.any((p) => p == 'ERBUMINE'),
          isFalse,
        );
      }
    });
  });
}
