// test/core/database/logic/clustering_rules_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';

import '../../../fixtures/seed_builder.dart';
import '../../../test_utils.dart' show setPrincipeNormalizedForAllPrinciples;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SQL-Level Clustering Rules', () {
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
      'CRITICAL: Néfopam and Adriblastine should be in separate groups via SQL',
      () async {
        await SeedBuilder()
            .inGroup('GROUP_NEFOPAM', 'NEFOPAM 20 mg')
            .addPrinceps(
              'ACUPAN 20 mg, comprimé',
              'CIP_NEFOPAM',
              cis: 'CIS_NEFOPAM',
              dosage: '20',
              form: 'Comprimé',
              lab: 'SANOFI',
            )
            .inGroup('GROUP_ADRIBLASTINE', 'ADRIBLASTINE 10 mg')
            .addPrinceps(
              'ADRIBLASTINE 10 mg, poudre',
              'CIP_ADRIBLASTINE',
              cis: 'CIS_ADRIBLASTINE',
              dosage: '10',
              form: 'Poudre',
              lab: 'PFIZER',
            )
            .insertInto(database);

        await database.databaseDao.insertBatchData(
          specialites: [],
          medicaments: [],
          principes: [
            {
              'code_cip': 'CIP_NEFOPAM',
              'principe': 'NEFOPAM',
              'dosage': '20',
              'dosage_unit': 'mg',
            },
            {
              'code_cip': 'CIP_ADRIBLASTINE',
              'principe': 'DOXORUBICINE',
              'dosage': '10',
              'dosage_unit': 'mg',
            },
          ],
          generiqueGroups: [],
          groupMembers: [],
        );

        await setPrincipeNormalizedForAllPrinciples(database);
        await dataInitializationService.runSummaryAggregationForTesting();

        final summaries = await database.catalogDao.getGenericGroupSummaries(
          
        );

        final nefopamGroups = summaries
            .where((s) => s.commonPrincipes.contains('NEFOPAM'))
            .toList();
        final adriblastineGroups = summaries
            .where((s) => s.commonPrincipes.contains('DOXORUBICINE'))
            .toList();

        expect(
          nefopamGroups,
          isNotEmpty,
          reason: 'Néfopam groups should exist',
        );
        expect(
          adriblastineGroups,
          isNotEmpty,
          reason: 'Adriblastine groups should exist',
        );

        for (final nefopamGroup in nefopamGroups) {
          expect(
            nefopamGroup.commonPrincipes,
            isNot(contains('DOXORUBICINE')),
            reason:
                'CRITICAL: Néfopam groups must NOT contain DOXORUBICINE (Adriblastine principle)',
          );
        }

        for (final adriblastineGroup in adriblastineGroups) {
          expect(
            adriblastineGroup.commonPrincipes,
            isNot(contains('NEFOPAM')),
            reason: 'CRITICAL: Adriblastine groups must NOT contain NEFOPAM',
          );
        }

        final nefopamGroupIds = nefopamGroups.map((g) => g.groupId).toSet();
        final adriblastineGroupIds = adriblastineGroups
            .map((g) => g.groupId)
            .toSet();

        expect(
          nefopamGroupIds.intersection(adriblastineGroupIds),
          isEmpty,
          reason:
              'CRITICAL: Néfopam and Adriblastine must be in completely separate groups',
        );
      },
    );

    test(
      'Mémantine groups with same commonPrincipes should cluster via SQL',
      () async {
        await SeedBuilder()
            .inGroup('GROUP_MEMANTINE_10', 'MEMANTINE 10 mg')
            .addPrinceps(
              'AXURA 10 mg, comprimé',
              'CIP_MEMANTINE_10',
              cis: 'CIS_MEMANTINE_10',
              dosage: '10',
              form: 'Comprimé',
              lab: 'LUNDBECK',
            )
            .inGroup('GROUP_MEMANTINE_20', 'MEMANTINE 20 mg')
            .addPrinceps(
              'AXURA 20 mg, comprimé',
              'CIP_MEMANTINE_20',
              cis: 'CIS_MEMANTINE_20',
              dosage: '20',
              form: 'Comprimé',
              lab: 'LUNDBECK',
            )
            .inGroup('GROUP_MEMANTINE_5', 'MEMANTINE 5 mg')
            .addPrinceps(
              'EBIXA 5 mg, solution',
              'CIP_MEMANTINE_5',
              cis: 'CIS_MEMANTINE_5',
              dosage: '5',
              form: 'Solution',
              lab: 'LUNDBECK',
            )
            .insertInto(database);

        await database.databaseDao.insertBatchData(
          specialites: [],
          medicaments: [],
          principes: [
            {
              'code_cip': 'CIP_MEMANTINE_10',
              'principe': 'MÉMANTINE (CHLORHYDRATE DE)',
              'dosage': '10',
              'dosage_unit': 'mg',
            },
            {
              'code_cip': 'CIP_MEMANTINE_20',
              'principe': 'MÉMANTINE (CHLORHYDRATE DE)',
              'dosage': '20',
              'dosage_unit': 'mg',
            },
            {
              'code_cip': 'CIP_MEMANTINE_5',
              'principe': 'MÉMANTINE (CHLORHYDRATE DE)',
              'dosage': '5',
              'dosage_unit': 'mg',
            },
          ],
          generiqueGroups: [],
          groupMembers: [],
        );

        await setPrincipeNormalizedForAllPrinciples(database);
        await dataInitializationService.runSummaryAggregationForTesting();

        final summaries = await database.catalogDao.getGenericGroupSummaries(
          
        );

        final memantineGroups = summaries
            .where(
              (s) =>
                  s.commonPrincipes.contains('MEMANTINE') ||
                  s.commonPrincipes.contains('MÉMANTINE'),
            )
            .toList();

        expect(
          memantineGroups.length,
          greaterThanOrEqualTo(3),
          reason: 'All Mémantine groups should be found',
        );

        final uniqueCommonPrincipes = memantineGroups
            .map((g) => g.commonPrincipes)
            .toSet()
            .where((p) => p.contains('MEMANTINE') || p.contains('MÉMANTINE'))
            .toList();

        expect(
          uniqueCommonPrincipes.length,
          equals(1),
          reason:
              'All Mémantine groups should share the same normalized commonPrincipes',
        );

        final memantineGroupIds = memantineGroups.map((g) => g.groupId).toSet();
        expect(
          memantineGroupIds,
          containsAll([
            'GROUP_MEMANTINE_10',
            'GROUP_MEMANTINE_20',
            'GROUP_MEMANTINE_5',
          ]),
          reason: 'All three Mémantine groups should be present',
        );
      },
    );

    test(
      'Combination products should preserve both molecules in SQL grouping',
      () async {
        await SeedBuilder()
            .inGroup(
              'GRP_TENORDATE',
              'ATENOLOL 50 mg + NIFEDIPINE 20 mg - TENORDATE',
            )
            .addGeneric(
              'ATENOLOL/NIFEDIPINE BIOGARAN',
              'CIP_TENORDATE',
              cis: 'CIS_TENORDATE',
              dosage: '50',
              form: 'Comprimé',
              lab: 'BIOGARAN',
            )
            .insertInto(database);

        await database.databaseDao.insertBatchData(
          specialites: [],
          medicaments: [],
          principes: [
            {
              'code_cip': 'CIP_TENORDATE',
              'principe': 'ATENOLOL',
              'dosage': '50',
              'dosage_unit': 'mg',
            },
            {
              'code_cip': 'CIP_TENORDATE',
              'principe': 'NIFEDIPINE',
              'dosage': '20',
              'dosage_unit': 'mg',
            },
          ],
          generiqueGroups: [],
          groupMembers: [],
        );

        await setPrincipeNormalizedForAllPrinciples(database);
        await dataInitializationService.runSummaryAggregationForTesting();

        final medicamentSummaries = await (database.select(
          database.medicamentSummary,
        )..where((tbl) => tbl.groupId.equals('GRP_TENORDATE'))).get();

        expect(
          medicamentSummaries,
          isNotEmpty,
          reason: 'Group summaries should be available',
        );

        final firstSummary = medicamentSummaries.first;
        final commonPrincipes = firstSummary.principesActifsCommuns.join(' ');

        expect(
          commonPrincipes.toUpperCase(),
          contains('ATENOLOL'),
          reason: 'Common principles must contain ATENOLOL',
        );
        expect(
          commonPrincipes.toUpperCase(),
          contains('NIFEDIPINE'),
          reason: 'Common principles must contain NIFEDIPINE',
        );

        expect(
          commonPrincipes.toUpperCase(),
          isNot(equals('ATENOLOL')),
          reason:
              'CRITICAL: Product name should not be truncated to only first molecule. '
              'Expected both ATENOLOL and NIFEDIPINE',
        );

        final genericGroupSummaries = await database.catalogDao
            .getGenericGroupSummaries(
              
            );

        final tenordateSummary = genericGroupSummaries.firstWhere(
          (s) => s.groupId == 'GRP_TENORDATE',
          orElse: () => throw Exception('TENORDATE group not found'),
        );

        expect(
          tenordateSummary.commonPrincipes.toUpperCase(),
          contains('ATENOLOL'),
          reason: 'Summary common principles must contain ATENOLOL',
        );
        expect(
          tenordateSummary.commonPrincipes.toUpperCase(),
          contains('NIFEDIPINE'),
          reason: 'Summary common principles must contain NIFEDIPINE',
        );
      },
    );
  });
}
