// test/core/database/logic/clustering_rules_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';

import '../../../fixtures/seed_builder.dart';
import '../../../test_utils.dart'
    show
        buildGeneriqueGroupCompanion,
        buildGroupMemberCompanion,
        buildPrincipeCompanion,
        setPrincipeNormalizedForAllPrinciples;

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
            .inGroup('GROUP_NEFOPAM', 'NÉFOPAM 20 mg')
            .addPrinceps(
              'ACUPAN 20 mg, comprimé',
              '3400930001001',
              cis: 'CIS_NEFOPAM',
              dosage: '20',
              form: 'Comprimé',
              lab: 'SANOFI',
            )
            .inGroup('GROUP_ADRIBLASTINE', 'ADRIBLASTINE 10 mg')
            .addPrinceps(
              'ADRIBLASTINE 10 mg, poudre',
              '3400930001002',
              cis: 'CIS_ADRIBLASTINE',
              dosage: '10',
              form: 'Poudre',
              lab: 'PFIZER',
            )
            .addGeneric(
              'ACUPAN Générique 20 mg, comprimé',
              '3400930001003',
              cis: 'CIS_NEFOPAM_GEN',
              dosage: '20',
              form: 'Comprimé',
              lab: 'GÉNÉRIQUE',
            )
            .addGeneric(
              'ADRIBLASTINE Générique 10 mg, poudre',
              '3400930001004',
              cis: 'CIS_ADRIBLASTINE_GEN',
              dosage: '10',
              form: 'Poudre',
              lab: 'GÉNÉRIQUE',
            )
            .insertInto(database);

        await database.databaseDao.insertBatchData(
          batchData: IngestionBatch(
            specialites: const [],
            medicaments: const [],
            principes: [
              buildPrincipeCompanion(
                codeCip: '3400930001001',
                principe: 'NÉFOPAM (CHLORHYDRATE DE)',
                dosage: '20',
                dosageUnit: 'mg',
              ),
              buildPrincipeCompanion(
                codeCip: '3400930001003',
                principe: 'NÉFOPAM',
                dosage: '20',
                dosageUnit: 'mg',
              ),
              buildPrincipeCompanion(
                codeCip: '3400930001002',
                principe: 'DOXORUBICINE',
                dosage: '10',
                dosageUnit: 'mg',
              ),
              buildPrincipeCompanion(
                codeCip: '3400930001004',
                principe: 'DOXORUBICINE',
                dosage: '10',
                dosageUnit: 'mg',
              ),
            ],
            generiqueGroups: [
              buildGeneriqueGroupCompanion(
                groupId: 'GROUP_NEFOPAM',
                libelle: 'NEFOPAM',
                princepsLabel: 'ACUPAN 20 mg, comprimé',
                moleculeLabel: 'NEFOPAM',
                rawLabel: 'NEFOPAM - ACUPAN 20 mg, comprimé',
                parsingMethod: 'relational',
              ),
              buildGeneriqueGroupCompanion(
                groupId: 'GROUP_ADRIBLASTINE',
                libelle: 'DOXORUBICINE',
                princepsLabel: 'ADRIBLASTINE 10 mg, poudre',
                moleculeLabel: 'DOXORUBICINE',
                rawLabel: 'DOXORUBICINE - ADRIBLASTINE 10 mg, poudre',
                parsingMethod: 'relational',
              ),
            ],
            groupMembers: [
              buildGroupMemberCompanion(
                groupId: 'GROUP_NEFOPAM',
                codeCip: '3400930001001',
                type: 0,
              ),
              buildGroupMemberCompanion(
                groupId: 'GROUP_NEFOPAM',
                codeCip: '3400930001003',
                type: 1,
              ),
              buildGroupMemberCompanion(
                groupId: 'GROUP_ADRIBLASTINE',
                codeCip: '3400930001002',
                type: 0,
              ),
              buildGroupMemberCompanion(
                groupId: 'GROUP_ADRIBLASTINE',
                codeCip: '3400930001004',
                type: 1,
              ),
            ],
            laboratories: const [],
          ),
        );

        await setPrincipeNormalizedForAllPrinciples(database);
        await dataInitializationService.runSummaryAggregationForTesting();

        final summaries = await database.catalogDao.getGenericGroupSummaries();

        final nefopamGroups = summaries
            .where((s) => s.groupId == 'GROUP_NEFOPAM')
            .toList();
        final adriblastineGroups = summaries
            .where((s) => s.groupId == 'GROUP_ADRIBLASTINE')
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
          batchData: IngestionBatch(
            specialites: const [],
            medicaments: const [],
            principes: [
              buildPrincipeCompanion(
                codeCip: 'CIP_MEMANTINE_10',
                principe: 'MÉMANTINE (CHLORHYDRATE DE)',
                dosage: '10',
                dosageUnit: 'mg',
              ),
              buildPrincipeCompanion(
                codeCip: 'CIP_MEMANTINE_20',
                principe: 'MÉMANTINE (CHLORHYDRATE DE)',
                dosage: '20',
                dosageUnit: 'mg',
              ),
              buildPrincipeCompanion(
                codeCip: 'CIP_MEMANTINE_5',
                principe: 'MÉMANTINE (CHLORHYDRATE DE)',
                dosage: '5',
                dosageUnit: 'mg',
              ),
            ],
            generiqueGroups: const [],
            groupMembers: const [],
            laboratories: const [],
          ),
        );

        await setPrincipeNormalizedForAllPrinciples(database);
        await dataInitializationService.runSummaryAggregationForTesting();

        final summaries = await database.catalogDao.getGenericGroupSummaries();

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
          batchData: IngestionBatch(
            specialites: const [],
            medicaments: const [],
            principes: [
              buildPrincipeCompanion(
                codeCip: 'CIP_TENORDATE',
                principe: 'ATENOLOL',
                dosage: '50',
                dosageUnit: 'mg',
              ),
              buildPrincipeCompanion(
                codeCip: 'CIP_TENORDATE',
                principe: 'NIFEDIPINE',
                dosage: '20',
                dosageUnit: 'mg',
              ),
            ],
            generiqueGroups: const [],
            groupMembers: const [],
            laboratories: const [],
          ),
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
            .getGenericGroupSummaries();

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
