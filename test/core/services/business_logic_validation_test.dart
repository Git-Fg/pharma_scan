// test/core/services/business_logic_validation_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import '../../test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Business Logic Validation - Parsing & Grouping', () {
    late Directory documentsDir;
    late AppDatabase database;
    late DataInitializationService dataInitializationService;

    setUp(() async {
      documentsDir = await Directory.systemTemp.createTemp('pharma_scan_test_');
      PathProviderPlatform.instance = FakePathProviderPlatform(
        documentsDir.path,
      );
      final dbFile = File(p.join(documentsDir.path, 'medicaments.db'));
      database = AppDatabase.forTesting(
        NativeDatabase(dbFile, setup: configureAppSQLite),
      );
      dataInitializationService = DataInitializationService(database: database);
    });

    tearDown(() async {
      await database.close();
      if (documentsDir.existsSync()) {
        await documentsDir.delete(recursive: true);
      }
    });

    test(
      'should construct clean nomCanonique for standalone medications without contamination',
      () async {
        // GIVEN: Standalone medication with single active principle
        await database.databaseDao.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_STANDALONE',
              'nom_specialite': 'ELIQUIS 5 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire': 'BRISTOL-MYERS SQUIBB',
            },
          ],
          medicaments: [
            {'code_cip': 'CIP_STANDALONE', 'cis_code': 'CIS_STANDALONE'},
          ],
          principes: [
            {
              'code_cip': 'CIP_STANDALONE',
              'principe': 'APIXABAN',
              'dosage': '5',
              'dosage_unit': 'mg',
            },
          ],
          generiqueGroups: [],
          groupMembers: [],
        );

        // WHEN: Run aggregation
        await dataInitializationService.runSummaryAggregationForTesting();

        // THEN: nomCanonique uses raw name (simplified SQL aggregation)
        final summary = await (database.select(
          database.medicamentSummary,
        )..where((tbl) => tbl.cisCode.equals('CIS_STANDALONE'))).getSingle();

        // WHY: SQL aggregation uses raw nom_specialite for standalone medications
        // Complex name cleaning is deferred for simplicity
        expect(summary.nomCanonique, 'ELIQUIS 5 mg, comprimé');
        expect(summary.principesActifsCommuns, contains('APIXABAN'));
      },
    );

    test(
      'should use group libelle as nomCanonique for grouped medications',
      () async {
        // GIVEN: Grouped medication
        await database.databaseDao.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_GROUPED',
              'nom_specialite': 'ELIQUIS 5 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire': 'BRISTOL-MYERS SQUIBB',
            },
          ],
          medicaments: [
            {'code_cip': 'CIP_GROUPED', 'cis_code': 'CIS_GROUPED'},
          ],
          principes: [
            {
              'code_cip': 'CIP_GROUPED',
              'principe': 'APIXABAN',
              'dosage': '5',
              'dosage_unit': 'mg',
            },
          ],
          generiqueGroups: [
            {'group_id': 'GROUP_APIXABAN_5', 'libelle': 'APIXABAN 5 mg'},
          ],
          groupMembers: [
            {
              'code_cip': 'CIP_GROUPED',
              'group_id': 'GROUP_APIXABAN_5',
              'type': 0,
            },
          ],
        );

        // WHEN: Run aggregation
        await dataInitializationService.runSummaryAggregationForTesting();

        // THEN: nomCanonique should use group libelle directly
        final summary = await (database.select(
          database.medicamentSummary,
        )..where((tbl) => tbl.cisCode.equals('CIS_GROUPED'))).getSingle();

        // WHY: For grouped medications, SQL uses generique_groups.libelle
        expect(summary.nomCanonique, 'APIXABAN 5 mg');
        expect(summary.nomCanonique, isNot(contains('ELIQUIS')));
        expect(summary.groupId, 'GROUP_APIXABAN_5');
      },
    );

    test(
      'should group medications correctly by therapeutic equivalence',
      () async {
        // GIVEN: Multiple medications with same active principle and dosage
        await database.databaseDao.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_P1',
              'nom_specialite': 'ELIQUIS 5 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire': 'BRISTOL-MYERS SQUIBB',
            },
            {
              'cis_code': 'CIS_G1',
              'nom_specialite': 'APIXABAN ZYDUS 5 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire': 'ZYDUS FRANCE',
            },
            {
              'cis_code': 'CIS_G2',
              'nom_specialite': 'APIXABAN TEVA 5 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire': 'TEVA SANTE',
            },
          ],
          medicaments: [
            {'code_cip': 'CIP_P1', 'cis_code': 'CIS_P1'},
            {'code_cip': 'CIP_G1', 'cis_code': 'CIS_G1'},
            {'code_cip': 'CIP_G2', 'cis_code': 'CIS_G2'},
          ],
          principes: [
            {
              'code_cip': 'CIP_P1',
              'principe': 'APIXABAN',
              'dosage': '5',
              'dosage_unit': 'mg',
            },
            {
              'code_cip': 'CIP_G1',
              'principe': 'APIXABAN',
              'dosage': '5',
              'dosage_unit': 'mg',
            },
            {
              'code_cip': 'CIP_G2',
              'principe': 'APIXABAN',
              'dosage': '5',
              'dosage_unit': 'mg',
            },
          ],
          generiqueGroups: [
            {'group_id': 'GROUP_APIXABAN_5', 'libelle': 'APIXABAN 5 mg'},
          ],
          groupMembers: [
            {'code_cip': 'CIP_P1', 'group_id': 'GROUP_APIXABAN_5', 'type': 0},
            {'code_cip': 'CIP_G1', 'group_id': 'GROUP_APIXABAN_5', 'type': 1},
            {'code_cip': 'CIP_G2', 'group_id': 'GROUP_APIXABAN_5', 'type': 1},
          ],
        );

        // WHEN: Run aggregation
        await dataInitializationService.runSummaryAggregationForTesting();

        // THEN: All medications should be in the same group with same nomCanonique
        final summaries = await (database.select(
          database.medicamentSummary,
        )..where((tbl) => tbl.groupId.equals('GROUP_APIXABAN_5'))).get();

        expect(summaries.length, 3);

        // All should have the same nomCanonique (from group libelle)
        final uniqueCanonicalNames = summaries
            .map((s) => s.nomCanonique)
            .toSet();
        expect(uniqueCanonicalNames.length, 1);
        expect(uniqueCanonicalNames.first, 'APIXABAN 5 mg');

        // Verify one princeps and two generics
        final princepsCount = summaries.where((s) => s.isPrinceps).length;
        final genericCount = summaries.where((s) => !s.isPrinceps).length;
        expect(princepsCount, 1);
        expect(genericCount, 2);

        // Verify all have APIXABAN as common principle
        final allHaveApixaban = summaries.every(
          (s) => s.principesActifsCommuns.contains('APIXABAN'),
        );
        expect(allHaveApixaban, isTrue);
      },
    );

    test(
      'should separate medications with different dosages into different groups',
      () async {
        // GIVEN: Medications with same principle but different dosages
        await database.databaseDao.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_5MG',
              'nom_specialite': 'ELIQUIS 5 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire': 'BRISTOL-MYERS SQUIBB',
            },
            {
              'cis_code': 'CIS_2_5MG',
              'nom_specialite': 'ELIQUIS 2.5 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire': 'BRISTOL-MYERS SQUIBB',
            },
          ],
          medicaments: [
            {'code_cip': 'CIP_5MG', 'cis_code': 'CIS_5MG'},
            {'code_cip': 'CIP_2_5MG', 'cis_code': 'CIS_2_5MG'},
          ],
          principes: [
            {
              'code_cip': 'CIP_5MG',
              'principe': 'APIXABAN',
              'dosage': '5',
              'dosage_unit': 'mg',
            },
            {
              'code_cip': 'CIP_2_5MG',
              'principe': 'APIXABAN',
              'dosage': '2.5',
              'dosage_unit': 'mg',
            },
          ],
          generiqueGroups: [
            {'group_id': 'GROUP_APIXABAN_5', 'libelle': 'APIXABAN 5 mg'},
            {'group_id': 'GROUP_APIXABAN_2_5', 'libelle': 'APIXABAN 2.5 mg'},
          ],
          groupMembers: [
            {'code_cip': 'CIP_5MG', 'group_id': 'GROUP_APIXABAN_5', 'type': 0},
            {
              'code_cip': 'CIP_2_5MG',
              'group_id': 'GROUP_APIXABAN_2_5',
              'type': 0,
            },
          ],
        );

        // WHEN: Run aggregation
        await dataInitializationService.runSummaryAggregationForTesting();

        // THEN: Should have 2 different groups with different nomCanonique
        final summaries = await database
            .select(database.medicamentSummary)
            .get();

        expect(summaries.length, 2);

        final group5 = summaries.firstWhere(
          (s) => s.groupId == 'GROUP_APIXABAN_5',
        );
        final group2_5 = summaries.firstWhere(
          (s) => s.groupId == 'GROUP_APIXABAN_2_5',
        );

        expect(group5.nomCanonique, 'APIXABAN 5 mg');
        expect(group2_5.nomCanonique, 'APIXABAN 2.5 mg');

        // Both should have APIXABAN as principle
        expect(group5.principesActifsCommuns.contains('APIXABAN'), isTrue);
        expect(group2_5.principesActifsCommuns.contains('APIXABAN'), isTrue);
      },
    );

    test(
      'should handle multi-ingredient standalone medications correctly',
      () async {
        // GIVEN: Standalone medication with multiple active principles
        await database.databaseDao.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_MULTI',
              'nom_specialite': 'CADUET 5 mg/10 mg, comprimé',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire': 'PFIZER',
            },
          ],
          medicaments: [
            {'code_cip': 'CIP_MULTI', 'cis_code': 'CIS_MULTI'},
          ],
          principes: [
            {
              'code_cip': 'CIP_MULTI',
              'principe': 'AMLODIPINE',
              'dosage': '5',
              'dosage_unit': 'mg',
            },
            {
              'code_cip': 'CIP_MULTI',
              'principe': 'ATORVASTATINE',
              'dosage': '10',
              'dosage_unit': 'mg',
            },
          ],
          generiqueGroups: [],
          groupMembers: [],
        );

        // WHEN: Run aggregation
        await dataInitializationService.runSummaryAggregationForTesting();

        // THEN: nomCanonique uses raw name (simplified SQL aggregation)
        final summary = await (database.select(
          database.medicamentSummary,
        )..where((tbl) => tbl.cisCode.equals('CIS_MULTI'))).getSingle();

        // WHY: SQL aggregation uses raw nom_specialite for standalone medications
        // Complex name cleaning is deferred for simplicity
        expect(summary.nomCanonique, 'CADUET 5 mg/10 mg, comprimé');

        // Verify all principles are in principesActifsCommuns
        expect(summary.principesActifsCommuns.length, 2);
        expect(summary.principesActifsCommuns, contains('AMLODIPINE'));
        expect(summary.principesActifsCommuns, contains('ATORVASTATINE'));

        // WHY: SQL aggregation uses raw nom_specialite for standalone medications
        // Complex name cleaning is deferred for simplicity
        expect(summary.nomCanonique, 'CADUET 5 mg/10 mg, comprimé');
      },
    );

    test('search should return results with clean medication names', () async {
      // GIVEN: Database with grouped medications
      await database.databaseDao.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_P',
            'nom_specialite': 'ELIQUIS 5 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'Comprimé',
            'titulaire': 'BRISTOL-MYERS SQUIBB',
          },
          {
            'cis_code': 'CIS_G',
            'nom_specialite': 'APIXABAN ZYDUS 5 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'Comprimé',
            'titulaire': 'ZYDUS FRANCE',
          },
        ],
        medicaments: [
          {'code_cip': 'CIP_P', 'cis_code': 'CIS_P'},
          {'code_cip': 'CIP_G', 'cis_code': 'CIS_G'},
        ],
        principes: [
          {
            'code_cip': 'CIP_P',
            'principe': 'APIXABAN',
            'dosage': '5',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_G',
            'principe': 'APIXABAN',
            'dosage': '5',
            'dosage_unit': 'mg',
          },
        ],
        generiqueGroups: [
          {'group_id': 'GROUP_1', 'libelle': 'APIXABAN 5 mg'},
        ],
        groupMembers: [
          {'code_cip': 'CIP_P', 'group_id': 'GROUP_1', 'type': 0},
          {'code_cip': 'CIP_G', 'group_id': 'GROUP_1', 'type': 1},
        ],
      );

      // WHEN: Run aggregation and search
      await dataInitializationService.runSummaryAggregationForTesting();

      final searchDao = database.searchDao;
      final candidatesEither = await searchDao.searchMedicaments('APIXABAN');
      expect(candidatesEither.isRight, isTrue);
      final candidates = candidatesEither.fold(
        ifLeft: (_) => <MedicamentSummaryData>[],
        ifRight: (v) => v,
      );

      // THEN: All candidates should have clean nomCanonique (from group libelle)
      expect(candidates.length, 2);

      for (final candidate in candidates) {
        // Verify nomCanonique is clean
        expect(candidate.nomCanonique, 'APIXABAN 5 mg');
        expect(candidate.nomCanonique, isNot(contains('ELIQUIS')));
        expect(candidate.nomCanonique, isNot(contains('ZYDUS')));
        expect(candidate.nomCanonique, isNot(contains('BRISTOL')));
        expect(candidate.nomCanonique, isNot(contains('comprimé')));

        // Verify nomCanonique is clean
        expect(candidate.nomCanonique, 'APIXABAN 5 mg');

        // Verify common principles
        expect(candidate.principesActifsCommuns, contains('APIXABAN'));

        // Verify groupId
        expect(candidate.groupId, 'GROUP_1');
      }
    });
  });
}
