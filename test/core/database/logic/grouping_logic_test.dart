// test/core/database/logic/grouping_logic_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import '../../../fixtures/seed_builder.dart';
import '../../../test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Grouping Logic - Parsing & Aggregation', () {
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

        // THEN: nomCanonique should use group libelle directly.
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

        expect(summary.nomCanonique, 'CADUET 5 mg/10 mg, comprimé');

        // Verify all principles are in principesActifsCommuns
        expect(summary.principesActifsCommuns.length, 2);
        expect(summary.principesActifsCommuns, contains('AMLODIPINE'));
        expect(summary.principesActifsCommuns, contains('ATORVASTATINE'));
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

      final catalogDao = database.catalogDao;
      final candidates = await catalogDao.searchMedicaments('APIXABAN');

      // THEN: All candidates should have clean nomCanonique (from group libelle)
      expect(candidates.length, 2);

      for (final candidate in candidates) {
        // Verify nomCanonique is clean
        expect(candidate.nomCanonique, 'APIXABAN 5 mg');
        expect(candidate.nomCanonique, isNot(contains('ELIQUIS')));
        expect(candidate.nomCanonique, isNot(contains('ZYDUS')));
        expect(candidate.nomCanonique, isNot(contains('BRISTOL')));
        expect(candidate.nomCanonique, isNot(contains('comprimé')));

        // Verify common principles
        expect(candidate.principesActifsCommuns, contains('APIXABAN'));

        // Verify groupId
        expect(candidate.groupId, 'GROUP_1');
      }
    });
  });

  group('classifyProductGroup - Complex SQL Logic', () {
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

    test('correctly splits Princeps, Generics, and Related Princeps', () async {
      // GIVEN: A group with princeps and generics, plus a related princeps from another group
      await SeedBuilder()
          .inGroup('GROUP_A', 'APIXABAN 5 mg')
          .addPrinceps(
            'ELIQUIS 5 mg, comprimé',
            'CIP_PRINCEPS_A',
            cis: 'CIS_PRINCEPS_A',
            dosage: '5',
            form: 'Comprimé',
            lab: 'BRISTOL-MYERS SQUIBB',
          )
          .addGeneric(
            'APIXABAN ZYDUS 5 mg, comprimé',
            'CIP_GENERIC_A',
            cis: 'CIS_GENERIC_A',
            dosage: '5',
            form: 'Comprimé',
            lab: 'ZYDUS FRANCE',
          )
          .inGroup('GROUP_B', 'APIXABAN 2.5 mg')
          .addPrinceps(
            'ELIQUIS 2.5 mg, comprimé',
            'CIP_PRINCEPS_B',
            cis: 'CIS_PRINCEPS_B',
            dosage: '2.5',
            form: 'Comprimé',
            lab: 'BRISTOL-MYERS SQUIBB',
          )
          .addGeneric(
            'APIXABAN TEVA 2.5 mg, comprimé',
            'CIP_GENERIC_B',
            cis: 'CIS_GENERIC_B',
            dosage: '2.5',
            form: 'Comprimé',
            lab: 'TEVA SANTE',
          )
          .insertInto(database);

      // WHY: Override default principes with specific ones for this test
      // GROUP_A: APIXABAN 5 mg
      // GROUP_B: APIXABAN 2.5 mg (related therapy)
      await database.databaseDao.insertBatchData(
        specialites: [],
        medicaments: [],
        principes: [
          {
            'code_cip': 'CIP_PRINCEPS_A',
            'principe': 'APIXABAN',
            'dosage': '5',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_GENERIC_A',
            'principe': 'APIXABAN',
            'dosage': '5',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_PRINCEPS_B',
            'principe': 'APIXABAN',
            'dosage': '2.5',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_GENERIC_B',
            'principe': 'APIXABAN',
            'dosage': '2.5',
            'dosage_unit': 'mg',
          },
        ],
        generiqueGroups: [],
        groupMembers: [],
      );

      await dataInitializationService.runSummaryAggregationForTesting();

      // WHEN: We fetch GROUP_A details
      final members = await database.catalogDao.getGroupDetails(
        'GROUP_A',
      );

      final related = await database.catalogDao.fetchRelatedPrinceps(
        'GROUP_A',
      );

      // THEN: Should have member rows from both GROUP_A and GROUP_B (same principles).
      expect(
        members.length,
        greaterThanOrEqualTo(4),
      ); // 2 from GROUP_A + 2 from GROUP_B

      // Verify GROUP_A princeps member exists
      final groupAPrinceps = members.firstWhere(
        (m) => m.isPrinceps && m.codeCip == 'CIP_PRINCEPS_A',
      );
      expect(groupAPrinceps.codeCip, 'CIP_PRINCEPS_A');

      // Verify GROUP_A generic member exists
      final groupAGeneric = members.firstWhere(
        (m) => !m.isPrinceps && m.codeCip == 'CIP_GENERIC_A',
      );
      expect(groupAGeneric.codeCip, 'CIP_GENERIC_A');

      // Verify GROUP_B princeps member exists (same principles as GROUP_A)
      final groupBPrinceps = members.firstWhere(
        (m) => m.isPrinceps && m.codeCip == 'CIP_PRINCEPS_B',
      );
      expect(groupBPrinceps.codeCip, 'CIP_PRINCEPS_B');

      // Verify GROUP_B generic member exists (same principles as GROUP_A)
      final groupBGeneric = members.firstWhere(
        (m) => !m.isPrinceps && m.codeCip == 'CIP_GENERIC_B',
      );
      expect(groupBGeneric.codeCip, 'CIP_GENERIC_B');

      expect(
        related,
        isEmpty,
        reason:
            'GROUP_B has same principles as GROUP_A (only APIXABAN), so it does not qualify as related princeps.',
      );
    });

    test(
      'Triangulation: Broken Generic inherits dosage from Princeps via SQL Join',
      () async {
        // GIVEN: A group with a clean Princeps and a "messy" Generic
        // The Generic has NO dosage in its name or composition (simulating bad data)
        await SeedBuilder()
            .inGroup('GROUP_BROKEN', 'MOLECULE 500 mg')
            .addPrinceps(
              'PRINCEPS 500 mg, comprimé',
              'CIP_P',
              cis: 'CIS_PRINCEPS',
              dosage: '500',
              form: 'Comprimé',
              lab: 'LABO PRINCEPS',
            )
            .addGeneric(
              'GENERIC LABO', // No dosage in name!
              'CIP_G',
              cis: 'CIS_GENERIC',
              form: 'Comprimé',
              lab: 'LABO GENERIC',
            )
            .insertInto(database);

        // WHY: Override default principes - Princeps has clean dosage, Generic has MISSING dosage
        // This simulates parsing failure or empty data for the generic
        await database.databaseDao.insertBatchData(
          specialites: [],
          medicaments: [],
          principes: [
            {
              'code_cip': 'CIP_P',
              'principe': 'MOLECULE',
              'dosage': '500',
              'dosage_unit': 'mg',
            },
            // Generic has missing dosage (simulating parsing failure or empty data)
            {'code_cip': 'CIP_G', 'principe': 'MOLECULE'},
          ],
          generiqueGroups: [],
          groupMembers: [],
        );

        await dataInitializationService.runSummaryAggregationForTesting();

        // WHEN: We fetch details, expecting dosage inheritance in view
        final members = await database.catalogDao.getGroupDetails(
          'GROUP_BROKEN',
        );

        // THEN: The group data should contain both princeps and generic
        expect(members.length, 2);

        final princepsMember = members.firstWhere((m) => m.isPrinceps);
        final genericMember = members.firstWhere((m) => !m.isPrinceps);

        expect(princepsMember.codeCip, 'CIP_P');
        expect(genericMember.codeCip, 'CIP_G');

        // Verify formatted dosage is available for both entries
        expect(
          princepsMember.formattedDosage,
          isNotEmpty,
          reason: 'Princeps should expose formatted dosage from principes',
        );
        expect(
          genericMember.formattedDosage,
          equals(princepsMember.formattedDosage),
          reason:
              'Generic without dosage should inherit princeps dosage through SQL view',
        );
      },
    );
  });

  group('getGenericGroupSummaries - Algorithmic Grouping', () {
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

    test('groups medications by shared principles correctly', () async {
      // GIVEN: Multiple groups with different principle combinations
      await database.databaseDao.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_P1',
            'nom_specialite': 'ELIQUIS 5 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'comprimé',
            'titulaire': 'BRISTOL-MYERS SQUIBB',
          },
          {
            'cis_code': 'CIS_G1',
            'nom_specialite': 'APIXABAN ZYDUS 5 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'comprimé',
            'titulaire': 'ZYDUS FRANCE',
          },
          {
            'cis_code': 'CIS_P2',
            'nom_specialite': 'ELIQUIS 2.5 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'comprimé',
            'titulaire': 'BRISTOL-MYERS SQUIBB',
          },
          {
            'cis_code': 'CIS_G2',
            'nom_specialite': 'APIXABAN TEVA 2.5 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'comprimé',
            'titulaire': 'TEVA SANTE',
          },
        ],
        medicaments: [
          {'code_cip': 'CIP_P1', 'cis_code': 'CIS_P1'},
          {'code_cip': 'CIP_G1', 'cis_code': 'CIS_G1'},
          {'code_cip': 'CIP_P2', 'cis_code': 'CIS_P2'},
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
            'code_cip': 'CIP_P2',
            'principe': 'APIXABAN',
            'dosage': '2.5',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_G2',
            'principe': 'APIXABAN',
            'dosage': '2.5',
            'dosage_unit': 'mg',
          },
        ],
        generiqueGroups: [
          {'group_id': 'GROUP_1', 'libelle': 'APIXABAN 5 mg'},
          {'group_id': 'GROUP_2', 'libelle': 'APIXABAN 2.5 mg'},
        ],
        groupMembers: [
          {'code_cip': 'CIP_P1', 'group_id': 'GROUP_1', 'type': 0},
          {'code_cip': 'CIP_G1', 'group_id': 'GROUP_1', 'type': 1},
          {'code_cip': 'CIP_P2', 'group_id': 'GROUP_2', 'type': 0},
          {'code_cip': 'CIP_G2', 'group_id': 'GROUP_2', 'type': 1},
        ],
      );

      await dataInitializationService.runSummaryAggregationForTesting();

      // WHEN: We get generic group summaries
      final summaries = await database.catalogDao.getGenericGroupSummaries(
        limit: 10,
      );

      // THEN: Should return both groups with correct common principles
      expect(summaries.length, 2);
      expect(
        summaries.map((s) => s.commonPrincipes).toSet(),
        containsAll(['APIXABAN']),
      );
    });

    test('filters groups without shared principles', () async {
      // GIVEN: A group where princeps and generic have different principles
      await database.databaseDao.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_P',
            'nom_specialite': 'PRINCEPS A 500 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'comprimé',
            'titulaire': 'LAB_P',
          },
          {
            'cis_code': 'CIS_G',
            'nom_specialite': 'GENERIC B 500 mg, comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'comprimé',
            'titulaire': 'LAB_G',
          },
        ],
        medicaments: [
          {'code_cip': 'CIP_P', 'cis_code': 'CIS_P'},
          {'code_cip': 'CIP_G', 'cis_code': 'CIS_G'},
        ],
        principes: [
          {'code_cip': 'CIP_P', 'principe': 'PRINCIPE_A'},
          {'code_cip': 'CIP_G', 'principe': 'PRINCIPE_B'},
        ],
        generiqueGroups: [
          {'group_id': 'GROUP_MIXED', 'libelle': 'MIXED GROUP'},
        ],
        groupMembers: [
          {'code_cip': 'CIP_P', 'group_id': 'GROUP_MIXED', 'type': 0},
          {'code_cip': 'CIP_G', 'group_id': 'GROUP_MIXED', 'type': 1},
        ],
      );

      await dataInitializationService.runSummaryAggregationForTesting();

      // WHEN: We get generic group summaries
      final summaries = await database.catalogDao.getGenericGroupSummaries(
        limit: 10,
      );

      // THEN: Should filter out groups without shared principles
      expect(
        summaries,
        isEmpty,
        reason:
            'Groups without a fully shared active principle set must be filtered out',
      );
    });
  });
}
