// test/core/database/daos/library_and_search_dao_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';

import '../../../test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late DataInitializationService dataInitializationService;
  late Directory documentsDir;

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp('pharma_scan_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(documentsDir.path);

    // For each test, create a fresh in-memory database
    final dbFile = File(p.join(documentsDir.path, 'medicaments.db'));
    database = AppDatabase.forTesting(
      NativeDatabase(dbFile, setup: configureAppSQLite),
    );

    dataInitializationService = DataInitializationService(database: database);
  });

  tearDown(() async {
    // Close the database and reset the locator after each test
    await database.close();
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
  });

  group('LibraryDao & SearchDao Logic', () {
    test('getGenericGroupSummaries returns deterministic principles', () async {
      await database.databaseDao.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_PRINCEPS',
            'nom_specialite': 'PRINCEPS 1',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'comprimé',
          },
          {
            'cis_code': 'CIS_GENERIC',
            'nom_specialite': 'GENERIC 1',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'comprimé',
          },
        ],
        medicaments: [
          {
            'code_cip': 'P1_CIP',
            'cis_code': 'CIS_PRINCEPS',
          },
          {'code_cip': 'G1_CIP', 'cis_code': 'CIS_GENERIC'},
        ],
        principes: [
          {'code_cip': 'P1_CIP', 'principe': 'PARACETAMOL'},
          {'code_cip': 'P1_CIP', 'principe': 'CAFEINE'},
          {'code_cip': 'G1_CIP', 'principe': 'PARACETAMOL'},
          {'code_cip': 'G1_CIP', 'principe': 'EXCIPIENT'},
        ],
        generiqueGroups: [
          {'group_id': 'GROUP_A', 'libelle': 'PARACETAMOL 500 mg'},
        ],
        groupMembers: [
          {'code_cip': 'P1_CIP', 'group_id': 'GROUP_A', 'type': 0},
          {'code_cip': 'G1_CIP', 'group_id': 'GROUP_A', 'type': 1},
        ],
      );

      // Populate MedicamentSummary table
      await dataInitializationService.runSummaryAggregationForTesting();

      final summaries = await database.catalogDao.getGenericGroupSummaries(
        limit: 10,
      );

      expect(summaries.length, 1);
      expect(summaries.first.commonPrincipes, 'PARACETAMOL');
    });

    test(
      'getGenericGroupSummaries skips groups without shared principles',
      () async {
        await database.databaseDao.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_P',
              'nom_specialite': 'PRINCEPS 2',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'comprimé',
            },
            {
              'cis_code': 'CIS_G',
              'nom_specialite': 'GENERIC 2',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'comprimé',
            },
          ],
          medicaments: [
            {'code_cip': 'P2_CIP', 'cis_code': 'CIS_P'},
            {'code_cip': 'G2_CIP', 'cis_code': 'CIS_G'},
          ],
          principes: [
            {'code_cip': 'P2_CIP', 'principe': 'PRINCIPE_A'},
            {'code_cip': 'G2_CIP', 'principe': 'PRINCIPE_B'},
          ],
          generiqueGroups: [
            {'group_id': 'GROUP_B', 'libelle': 'MIXED GROUP'},
          ],
          groupMembers: [
            {'code_cip': 'P2_CIP', 'group_id': 'GROUP_B', 'type': 0},
            {'code_cip': 'G2_CIP', 'group_id': 'GROUP_B', 'type': 1},
          ],
        );

        final summaries = await database.catalogDao.getGenericGroupSummaries(
          limit: 10,
        );

        expect(
          summaries,
          isEmpty,
          reason:
              'Groups without a fully shared active principle set must be filtered out.',
        );
      },
    );

    test('should return correct database statistics', () async {
      // GIVEN: A database with medicaments, principes, and groups
      await database.databaseDao.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_PRINCEPS_1',
            'nom_specialite': 'PRINCEPS 1',
            'procedure_type': 'Autorisation',
          },
          {
            'cis_code': 'CIS_PRINCEPS_2',
            'nom_specialite': 'PRINCEPS 2',
            'procedure_type': 'Autorisation',
          },
          {
            'cis_code': 'CIS_GENERIC_1',
            'nom_specialite': 'GENERIC 1',
            'procedure_type': 'Autorisation',
          },
          {
            'cis_code': 'CIS_GENERIC_2',
            'nom_specialite': 'GENERIC 2',
            'procedure_type': 'Autorisation',
          },
        ],
        medicaments: [
          {
            'code_cip': 'PRINCEPS_1',
            'cis_code': 'CIS_PRINCEPS_1',
          },
          {
            'code_cip': 'PRINCEPS_2',
            'cis_code': 'CIS_PRINCEPS_2',
          },
          {
            'code_cip': 'GENERIC_1',
            'cis_code': 'CIS_GENERIC_1',
          },
          {
            'code_cip': 'GENERIC_2',
            'cis_code': 'CIS_GENERIC_2',
          },
        ],
        principes: [
          {'code_cip': 'PRINCEPS_1', 'principe': 'ACTIVE_PRINCIPLE_1'},
          {'code_cip': 'PRINCEPS_2', 'principe': 'ACTIVE_PRINCIPLE_1'},
          {'code_cip': 'GENERIC_1', 'principe': 'ACTIVE_PRINCIPLE_1'},
          {'code_cip': 'GENERIC_2', 'principe': 'ACTIVE_PRINCIPLE_2'},
        ],
        generiqueGroups: [
          {'group_id': 'GROUP_1', 'libelle': 'TEST GROUP 1'},
        ],
        groupMembers: [
          {'code_cip': 'PRINCEPS_1', 'group_id': 'GROUP_1', 'type': 0},
          {'code_cip': 'GENERIC_1', 'group_id': 'GROUP_1', 'type': 1},
          {'code_cip': 'GENERIC_2', 'group_id': 'GROUP_1', 'type': 1},
        ],
      );

      // WHEN: We get database stats
      final stats = await database.catalogDao.getDatabaseStats();

      // THEN: Statistics are correct
      expect(stats['total_princeps'], 2); // 4 total - 2 generics = 2 princeps
      expect(stats['total_generiques'], 2);
      expect(stats['total_principes'], 2); // 2 distinct principles
      expect(stats['avg_gen_per_principe'], 1.0); // 2 generics / 2 principles
    });

    test('searchMedicaments returns canonical princeps and generics', () async {
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
          {
            'code_cip': 'CIP_G',
            'cis_code': 'CIS_G',
          },
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

      await dataInitializationService.runSummaryAggregationForTesting();

      final catalogDao = database.catalogDao;
      final candidates = await catalogDao.searchMedicaments('APIXABAN');
      expect(candidates.length, 2);

      final princeps = candidates.firstWhere(
        (candidate) => candidate.isPrinceps,
      );
      final generic = candidates.firstWhere(
        (candidate) => !candidate.isPrinceps,
      );

      expect(princeps.groupId, 'GROUP_1');
      expect(princeps.principesActifsCommuns, contains('APIXABAN'));
      expect(princeps.nomCanonique, 'APIXABAN 5 mg');

      expect(generic.groupId, 'GROUP_1');
      expect(generic.nomCanonique, 'APIXABAN 5 mg');
      expect(generic.principesActifsCommuns, contains('APIXABAN'));
    });

    test('searchMedicaments preserves procedure type metadata', () async {
      await database.databaseDao.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_CONV',
            'nom_specialite': 'MEDICAMENT CONVENTIONNEL',
            'procedure_type': 'Autorisation',
          },
          {
            'cis_code': 'CIS_HOMEO',
            'nom_specialite': 'PRODUIT HOMEOPATHIQUE',
            'procedure_type': 'Enreg homéo (Proc. Nat.)',
          },
        ],
        medicaments: [
          {
            'code_cip': 'CIP_CONV',
            'cis_code': 'CIS_CONV',
          },
          {
            'code_cip': 'CIP_HOMEO',
            'cis_code': 'CIS_HOMEO',
          },
        ],
        principes: [
          {
            'code_cip': 'CIP_CONV',
            'principe': 'PRINCIPE_A',
            'dosage': '1',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_HOMEO',
            'principe': 'PRINCIPE_B',
            'dosage': '1',
            'dosage_unit': 'mg',
          },
        ],
        generiqueGroups: [
          {'group_id': 'GROUP_CONV', 'libelle': 'Conventional Group'},
          {'group_id': 'GROUP_HOMEO', 'libelle': 'Homeopathic Group'},
        ],
        groupMembers: [
          {'code_cip': 'CIP_CONV', 'group_id': 'GROUP_CONV', 'type': 0},
          {'code_cip': 'CIP_HOMEO', 'group_id': 'GROUP_HOMEO', 'type': 0},
        ],
      );

      await dataInitializationService.runSummaryAggregationForTesting();

      final result = await database.catalogDao.searchMedicaments('GROUP');
      expect(result.length, 2);

      // Get specialite data to check procedure type
      final homeoSpec = database.select(database.specialites)
        ..where((tbl) => tbl.cisCode.equals('CIS_HOMEO'));
      final convSpec = database.select(database.specialites)
        ..where((tbl) => tbl.cisCode.equals('CIS_CONV'));
      final homeoSpecData = await homeoSpec.getSingleOrNull();
      final convSpecData = await convSpec.getSingleOrNull();

      expect(homeoSpecData?.procedureType, contains('homéo'));
      expect(convSpecData?.procedureType, 'Autorisation');
    });

    test('searchMedicaments sorts by canonical name', () async {
      await database.databaseDao.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_B',
            'nom_specialite': 'BETA MEDIC',
            'procedure_type': 'Autorisation',
          },
          {
            'cis_code': 'CIS_A',
            'nom_specialite': 'ALPHA MEDIC',
            'procedure_type': 'Autorisation',
          },
        ],
        medicaments: [
          {'code_cip': 'CIP_B', 'cis_code': 'CIS_B'},
          {'code_cip': 'CIP_A', 'cis_code': 'CIS_A'},
        ],
        principes: [
          {
            'code_cip': 'CIP_B',
            'principe': 'ACTIVE_B',
            'dosage': '1',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_A',
            'principe': 'ACTIVE_A',
            'dosage': '1',
            'dosage_unit': 'mg',
          },
        ],
        generiqueGroups: [
          {'group_id': 'GROUP_B', 'libelle': 'Group B'},
          {'group_id': 'GROUP_A', 'libelle': 'Group A'},
        ],
        groupMembers: [
          {'code_cip': 'CIP_B', 'group_id': 'GROUP_B', 'type': 0},
          {'code_cip': 'CIP_A', 'group_id': 'GROUP_A', 'type': 0},
        ],
      );

      await dataInitializationService.runSummaryAggregationForTesting();

      final result = await database.catalogDao.searchMedicaments('Group');
      expect(result.length, 2);
      final names = result.map((s) => s.nomCanonique).toList();
      final sortedNames = [...names]..sort((a, b) => a.compareTo(b));
      expect(names, equals(sortedNames));
    });

    test('should classify groups with varied generic types', () async {
      // GIVEN: A group with 2 princeps and 3 generics grouped by laboratory
      await database.databaseDao.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_PRINCEPS_1',
            'nom_specialite': 'PRINCEPS 1',
            'procedure_type': 'Autorisation',
          },
          {
            'cis_code': 'CIS_PRINCEPS_2',
            'nom_specialite': 'PRINCEPS 2',
            'procedure_type': 'Autorisation',
          },
          {
            'cis_code': 'CIS_GENERIC_1',
            'nom_specialite': 'GENERIC TYPE 1',
            'procedure_type': 'Autorisation',
            'titulaire': 'LABORATORY_A',
          },
          {
            'cis_code': 'CIS_GENERIC_2',
            'nom_specialite': 'GENERIC TYPE 2',
            'procedure_type': 'Autorisation',
            'titulaire': 'LABORATORY_B',
          },
          {
            'cis_code': 'CIS_GENERIC_4',
            'nom_specialite': 'GENERIC TYPE 4',
            'procedure_type': 'Autorisation',
            'titulaire': 'LABORATORY_C',
          },
        ],
        medicaments: [
          {
            'code_cip': 'PRINCEPS_1_CIP',
            'cis_code': 'CIS_PRINCEPS_1',
          },
          {
            'code_cip': 'PRINCEPS_2_CIP',
            'cis_code': 'CIS_PRINCEPS_2',
          },
          {
            'code_cip': 'GENERIC_1_CIP',
            'cis_code': 'CIS_GENERIC_1',
          },
          {
            'code_cip': 'GENERIC_2_CIP',
            'cis_code': 'CIS_GENERIC_2',
          },
          {
            'code_cip': 'GENERIC_4_CIP',
            'cis_code': 'CIS_GENERIC_4',
          },
        ],
        principes: [],
        generiqueGroups: [
          {'group_id': 'GROUP_1', 'libelle': 'TEST GROUP'},
        ],
        groupMembers: [
          {'code_cip': 'PRINCEPS_1_CIP', 'group_id': 'GROUP_1', 'type': 0},
          {'code_cip': 'PRINCEPS_2_CIP', 'group_id': 'GROUP_1', 'type': 0},
          {
            'code_cip': 'GENERIC_1_CIP',
            'group_id': 'GROUP_1',
            'type': 1,
          }, // Type 1
          {
            'code_cip': 'GENERIC_2_CIP',
            'group_id': 'GROUP_1',
            'type': 1,
          }, // Type 2 stored as 1
          {
            'code_cip': 'GENERIC_4_CIP',
            'group_id': 'GROUP_1',
            'type': 1,
          }, // Type 4 stored as 1
        ],
      );

      await dataInitializationService.runSummaryAggregationForTesting();

      // WHEN: We fetch group details
      final members = await database.catalogDao.getGroupDetails(
        'GROUP_1',
      );

      // THEN: The group data should contain 2 princeps and 3 generic members
      final princepsMembers = members
          .where((member) => member.isPrinceps)
          .toList();
      final genericMembers = members
          .where((member) => !member.isPrinceps)
          .toList();

      expect(princepsMembers.length, 2);
      expect(genericMembers.length, 3);

      expect(
        princepsMembers.map((p) => p.codeCip),
        containsAll(['PRINCEPS_1_CIP', 'PRINCEPS_2_CIP']),
      );
      final allGenericCips = genericMembers.map((m) => m.codeCip).toList();
      expect(
        allGenericCips,
        containsAll(['GENERIC_1_CIP', 'GENERIC_2_CIP', 'GENERIC_4_CIP']),
      );
      final allLabs = genericMembers
          .map((m) => m.summaryTitulaire ?? m.officialTitulaire ?? '')
          .where((lab) => lab.isNotEmpty)
          .toSet();
      expect(
        allLabs,
        containsAll(['LABORATORY_A', 'LABORATORY_B', 'LABORATORY_C']),
      );
    });

    test(
      'classifyProductGroup should surface related princeps sharing active principles',
      () async {
        await database.databaseDao.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_PRINCEPS_A',
              'nom_specialite': 'PRINCEPS A',
              'procedure_type': 'Autorisation',
            },
            {
              'cis_code': 'CIS_GENERIC_A',
              'nom_specialite': 'GENERIC A1',
              'procedure_type': 'Autorisation',
            },
            {
              'cis_code': 'CIS_PRINCEPS_B',
              'nom_specialite': 'PRINCEPS B',
              'procedure_type': 'Autorisation',
            },
            {
              'cis_code': 'CIS_GENERIC_B',
              'nom_specialite': 'GENERIC B1',
              'procedure_type': 'Autorisation',
            },
          ],
          medicaments: [
            {
              'code_cip': 'PRINCEPS_A_CIP',
              'cis_code': 'CIS_PRINCEPS_A',
            },
            {
              'code_cip': 'GENERIC_A_CIP',
              'cis_code': 'CIS_GENERIC_A',
            },
            {
              'code_cip': 'PRINCEPS_B_CIP',
              'cis_code': 'CIS_PRINCEPS_B',
            },
            {
              'code_cip': 'GENERIC_B_CIP',
              'cis_code': 'CIS_GENERIC_B',
            },
          ],
          principes: [
            {'code_cip': 'PRINCEPS_A_CIP', 'principe': 'PARACETAMOL'},
            {'code_cip': 'GENERIC_A_CIP', 'principe': 'PARACETAMOL'},
            {'code_cip': 'PRINCEPS_B_CIP', 'principe': 'PARACETAMOL'},
            {'code_cip': 'PRINCEPS_B_CIP', 'principe': 'CAFFEINE'},
            {'code_cip': 'GENERIC_B_CIP', 'principe': 'PARACETAMOL'},
            {'code_cip': 'GENERIC_B_CIP', 'principe': 'CAFFEINE'},
          ],
          generiqueGroups: [
            {'group_id': 'GROUP_A', 'libelle': 'PARA GROUP 1'},
            {'group_id': 'GROUP_B', 'libelle': 'PARA GROUP 2'},
          ],
          groupMembers: [
            {'code_cip': 'PRINCEPS_A_CIP', 'group_id': 'GROUP_A', 'type': 0},
            {'code_cip': 'GENERIC_A_CIP', 'group_id': 'GROUP_A', 'type': 1},
            {'code_cip': 'PRINCEPS_B_CIP', 'group_id': 'GROUP_B', 'type': 0},
            {'code_cip': 'GENERIC_B_CIP', 'group_id': 'GROUP_B', 'type': 1},
          ],
        );

        await dataInitializationService.runSummaryAggregationForTesting();

        final members = await database.catalogDao.getGroupDetails(
          'GROUP_A',
        );

        final related = await database.catalogDao.fetchRelatedPrinceps(
          'GROUP_A',
        );

        expect(members.where((m) => m.isPrinceps).length, 1);
        expect(related.length, 1);
        final relatedPrinceps = related.first;
        expect(relatedPrinceps.codeCip, 'PRINCEPS_B_CIP');
        expect(
          relatedPrinceps.principesActifsCommuns,
          containsAll(['PARACETAMOL', 'CAFFEINE']),
        );
      },
    );
  });

  group('group details view', () {
    test('returns canonical classification for deterministic group', () async {
      await database.databaseDao.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_PRINCEPS_MAIN',
            'nom_specialite': 'PARA PRINCEPS 500 mg comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'Comprimé',
            'titulaire': 'LAB PRINCEPS',
          },
          {
            'cis_code': 'CIS_GENERIC_A',
            'nom_specialite': 'PARA GENERIC 500 mg comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'Comprimé',
            'titulaire': 'LAB GENERIC A',
          },
          {
            'cis_code': 'CIS_GENERIC_B',
            'nom_specialite': 'PARA GENERIC 500 mg, comprimé pelliculé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'Comprimé',
            'titulaire': 'LAB GENERIC B',
          },
          {
            'cis_code': 'CIS_PRINCEPS_SECOND',
            'nom_specialite': 'PARA PRINCEPS B 500 mg comprimé',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'Comprimé effervescent',
            'titulaire': 'LAB SECOND',
          },
        ],
        medicaments: [
          {
            'code_cip': 'CIP_PRINCEPS_MAIN',
            'cis_code': 'CIS_PRINCEPS_MAIN',
          },
          {
            'code_cip': 'CIP_GENERIC_A',
            'cis_code': 'CIS_GENERIC_A',
          },
          {
            'code_cip': 'CIP_GENERIC_B',
            'cis_code': 'CIS_GENERIC_B',
          },
          {
            'code_cip': 'CIP_PRINCEPS_SECOND',
            'cis_code': 'CIS_PRINCEPS_SECOND',
          },
        ],
        principes: [
          {
            'code_cip': 'CIP_PRINCEPS_MAIN',
            'principe': 'PARACETAMOL',
            'dosage': '500',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_GENERIC_A',
            'principe': 'PARACETAMOL',
            'dosage': '500',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_GENERIC_B',
            'principe': 'PARACETAMOL',
            'dosage': '500',
            'dosage_unit': 'mg',
          },
          {
            'code_cip': 'CIP_PRINCEPS_SECOND',
            'principe': 'PARACETAMOL',
            'dosage': '500',
            'dosage_unit': 'mg',
          },
          // WHY: GROUP_SECOND must have PARACETAMOL (shared) PLUS an additional ingredient to be a related therapy
          {
            'code_cip': 'CIP_PRINCEPS_SECOND',
            'principe': 'CAFFEINE',
            'dosage': '50',
            'dosage_unit': 'mg',
          },
        ],
        generiqueGroups: [
          {'group_id': 'GROUP_MAIN', 'libelle': 'PARACETAMOL 500 MG'},
          {'group_id': 'GROUP_SECOND', 'libelle': 'PARACETAMOL B 500 MG'},
        ],
        groupMembers: [
          {
            'code_cip': 'CIP_PRINCEPS_MAIN',
            'group_id': 'GROUP_MAIN',
            'type': 0,
          },
          {'code_cip': 'CIP_GENERIC_A', 'group_id': 'GROUP_MAIN', 'type': 1},
          {'code_cip': 'CIP_GENERIC_B', 'group_id': 'GROUP_MAIN', 'type': 1},
          {
            'code_cip': 'CIP_PRINCEPS_SECOND',
            'group_id': 'GROUP_SECOND',
            'type': 0,
          },
        ],
      );

      await dataInitializationService.runSummaryAggregationForTesting();

      final members = await database.catalogDao.getGroupDetails(
        'GROUP_MAIN',
      );

      final related = await database.catalogDao.fetchRelatedPrinceps(
        'GROUP_MAIN',
      );

      expect(members, isNotEmpty);

      final title = members.first.princepsDeReference;
      final commonPrincipes = members.first.principesActifsCommuns;
      final distinctDosages = members
          .map((m) => m.formattedDosage)
          .whereType<String>()
          .toSet();
      final distinctForms = members
          .map((m) => m.formePharmaceutique?.trim())
          .whereType<String>()
          .toSet();

      expect(title.contains('PARA'), isTrue);
      expect(commonPrincipes, ['PARACETAMOL']);
      expect(distinctDosages, contains('500 mg'));
      expect(distinctForms, contains('Comprimé'));

      final princepsMembers = members
          .where((m) => m.isPrinceps)
          .toList(growable: false);
      final genericMembers = members
          .where((m) => !m.isPrinceps)
          .toList(growable: false);

      expect(princepsMembers.length, 1);
      expect(genericMembers.length, 2);
      expect(related.length, 1);
      expect(related.first.codeCip, 'CIP_PRINCEPS_SECOND');
    });

    test('returns null when group has no members', () async {
      final members = await database.catalogDao.getGroupDetails(
        'MISSING',
      );
      expect(members, isEmpty);
    });
  });
}
