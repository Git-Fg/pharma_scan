// test/database_service_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/mappers.dart';
import 'package:pharma_scan/core/services/drift_database_service.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/features/explorer/repositories/explorer_repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late DriftDatabaseService dbService;
  late DataInitializationService dataInitializationService;
  late Directory documentsDir;

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp('pharma_scan_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      documentsDir.path,
    );

    // For each test, create a fresh in-memory database
    final dbFile = File(p.join(documentsDir.path, 'medicaments.db'));
    database = AppDatabase.forTesting(NativeDatabase(dbFile));

    dbService = DriftDatabaseService(database);
    dataInitializationService = DataInitializationService(
      databaseService: dbService,
    );
  });

  tearDown(() async {
    // Close the database and reset the locator after each test
    await database.close();
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
  });

  group('DriftDatabaseService with Drift', () {
    test('getGenericGroupSummaries returns deterministic principles', () async {
      await dbService.insertBatchData(
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
            'nom': 'PRINCEPS 1',
            'cis_code': 'CIS_PRINCEPS',
          },
          {'code_cip': 'G1_CIP', 'nom': 'GENERIC 1', 'cis_code': 'CIS_GENERIC'},
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

      final summaries = await dbService.getGenericGroupSummaries(
        limit: 10,
        offset: 0,
      );

      expect(summaries.length, 1);
      expect(summaries.first.commonPrincipes, 'PARACETAMOL');
    });

    test(
      'getGenericGroupSummaries skips groups without shared principles',
      () async {
        await dbService.insertBatchData(
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
            {'code_cip': 'P2_CIP', 'nom': 'PRINCEPS 2', 'cis_code': 'CIS_P'},
            {'code_cip': 'G2_CIP', 'nom': 'GENERIC 2', 'cis_code': 'CIS_G'},
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

        final summaries = await dbService.getGenericGroupSummaries(
          limit: 10,
          offset: 0,
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
      await dbService.insertBatchData(
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
            'nom': 'PRINCEPS 1',
            'cis_code': 'CIS_PRINCEPS_1',
          },
          {
            'code_cip': 'PRINCEPS_2',
            'nom': 'PRINCEPS 2',
            'cis_code': 'CIS_PRINCEPS_2',
          },
          {
            'code_cip': 'GENERIC_1',
            'nom': 'GENERIC 1',
            'cis_code': 'CIS_GENERIC_1',
          },
          {
            'code_cip': 'GENERIC_2',
            'nom': 'GENERIC 2',
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
      final stats = await dbService.getDatabaseStats();

      // THEN: Statistics are correct
      expect(stats['total_princeps'], 2); // 4 total - 2 generics = 2 princeps
      expect(stats['total_generiques'], 2);
      expect(stats['total_principes'], 2); // 2 distinct principles
      expect(stats['avg_gen_per_principe'], 1.0); // 2 generics / 2 principles
    });

    test(
      'getAllSearchCandidates returns canonical princeps and generics',
      () async {
        await dbService.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_P',
              'nom_specialite': 'DOLIPRANE 500mg',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Comprimé',
              'titulaire': 'LABO P',
            },
            {
              'cis_code': 'CIS_G',
              'nom_specialite': 'DOLIPRANE GENERIQUE',
              'procedure_type': 'Autorisation',
              'forme_pharmaceutique': 'Gélule',
              'titulaire': 'LABO G',
            },
          ],
          medicaments: [
            {
              'code_cip': 'CIP_P',
              'nom': 'DOLIPRANE 500mg',
              'cis_code': 'CIS_P',
            },
            {
              'code_cip': 'CIP_G',
              'nom': 'DOLIPRANE GENERIQUE',
              'cis_code': 'CIS_G',
            },
          ],
          principes: [
            {'code_cip': 'CIP_P', 'principe': 'PARACETAMOL'},
            {'code_cip': 'CIP_G', 'principe': 'PARACETAMOL'},
          ],
          generiqueGroups: [
            {'group_id': 'GROUP_1', 'libelle': 'Doliprane'},
          ],
          groupMembers: [
            {'code_cip': 'CIP_P', 'group_id': 'GROUP_1', 'type': 0},
            {'code_cip': 'CIP_G', 'group_id': 'GROUP_1', 'type': 1},
          ],
        );

        await dataInitializationService.runSummaryAggregationForTesting();

        final repository = ExplorerRepository(dbService);
        final candidates = await repository.getAllSearchCandidates();
        expect(candidates.length, 2);

        final princeps = candidates.firstWhere(
          (candidate) => candidate.isPrinceps,
        );
        final generic = candidates.firstWhere(
          (candidate) => !candidate.isPrinceps,
        );

        expect(princeps.groupId, 'GROUP_1');
        expect(princeps.commonPrinciples, contains('PARACETAMOL'));
        expect(princeps.medicament.nom, 'DOLIPRANE 500mg');
        expect(princeps.medicament.titulaire, 'LABO P');
        expect(princeps.medicament.formePharmaceutique, 'Comprimé');

        expect(generic.groupId, 'GROUP_1');
        expect(generic.medicament.codeCip, 'CIP_G');
        expect(generic.nomCanonique, contains('DOLIPRANE'));
        expect(generic.commonPrinciples, contains('PARACETAMOL'));
        expect(generic.medicament.formePharmaceutique, 'Gélule');
      },
    );

    test('getAllSearchCandidates preserves procedure type metadata', () async {
      await dbService.insertBatchData(
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
            'nom': 'MEDICAMENT CONVENTIONNEL',
            'cis_code': 'CIS_CONV',
          },
          {
            'code_cip': 'CIP_HOMEO',
            'nom': 'PRODUIT HOMEOPATHIQUE',
            'cis_code': 'CIS_HOMEO',
          },
        ],
        principes: [],
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

      final result = await dbService.getAllSearchCandidates();
      expect(result.length, 2);

      // Get specialite data to check procedure type
      final homeoSpec = dbService.database.select(
        dbService.database.specialites,
      )..where((tbl) => tbl.cisCode.equals('CIS_HOMEO'));
      final convSpec = dbService.database.select(dbService.database.specialites)
        ..where((tbl) => tbl.cisCode.equals('CIS_CONV'));
      final homeoSpecData = await homeoSpec.getSingleOrNull();
      final convSpecData = await convSpec.getSingleOrNull();

      expect(homeoSpecData?.procedureType, contains('homéo'));
      expect(convSpecData?.procedureType, 'Autorisation');
    });

    test('getAllSearchCandidates sorts by canonical name', () async {
      await dbService.insertBatchData(
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
          {'code_cip': 'CIP_B', 'nom': 'BETA MEDIC', 'cis_code': 'CIS_B'},
          {'code_cip': 'CIP_A', 'nom': 'ALPHA MEDIC', 'cis_code': 'CIS_A'},
        ],
        principes: [],
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

      final result = await dbService.getAllSearchCandidates();
      expect(result.length, 2);
      final names = result.map((s) => s.nomCanonique).toList();
      final sortedNames = [...names]..sort((a, b) => a.compareTo(b));
      expect(names, equals(sortedNames));
    });

    test('should classify groups with varied generic types', () async {
      // GIVEN: A group with 2 princeps and 3 generics grouped by laboratory
      await dbService.insertBatchData(
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
            'nom': 'PRINCEPS 1',
            'cis_code': 'CIS_PRINCEPS_1',
          },
          {
            'code_cip': 'PRINCEPS_2_CIP',
            'nom': 'PRINCEPS 2',
            'cis_code': 'CIS_PRINCEPS_2',
          },
          {
            'code_cip': 'GENERIC_1_CIP',
            'nom': 'GENERIC TYPE 1',
            'cis_code': 'CIS_GENERIC_1',
          },
          {
            'code_cip': 'GENERIC_2_CIP',
            'nom': 'GENERIC TYPE 2',
            'cis_code': 'CIS_GENERIC_2',
          },
          {
            'code_cip': 'GENERIC_4_CIP',
            'nom': 'GENERIC TYPE 4',
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

      // WHEN: We classify the group
      final classificationDto = await dbService.classifyProductGroup('GROUP_1');
      final classification = classificationDto?.toDomain();

      // THEN: The classification should contain 2 princeps and 3 generic buckets
      expect(
        classification!.princeps.expand((bucket) => bucket.medicaments).length,
        2,
      );
      expect(
        classification.generics.expand((bucket) => bucket.medicaments).length,
        3,
      );
      expect(
        classification.princeps
            .expand((bucket) => bucket.medicaments)
            .map((p) => p.codeCip),
        containsAll(['PRINCEPS_1_CIP', 'PRINCEPS_2_CIP']),
      );
      // Verify all generic products are present across all groups
      final allGenericCips = classification.generics
          .expand((bucket) => bucket.medicaments.map((m) => m.codeCip))
          .toList();
      expect(
        allGenericCips,
        containsAll(['GENERIC_1_CIP', 'GENERIC_2_CIP', 'GENERIC_4_CIP']),
      );
      // Verify grouping by laboratory
      expect(
        classification.generics.expand((bucket) => bucket.laboratories).toSet(),
        containsAll(['LABORATORY_A', 'LABORATORY_B', 'LABORATORY_C']),
      );
    });

    test(
      'classifyProductGroup should surface related princeps sharing active principles',
      () async {
        await dbService.insertBatchData(
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
              'nom': 'PRINCEPS A',
              'cis_code': 'CIS_PRINCEPS_A',
            },
            {
              'code_cip': 'GENERIC_A_CIP',
              'nom': 'GENERIC A1',
              'cis_code': 'CIS_GENERIC_A',
            },
            {
              'code_cip': 'PRINCEPS_B_CIP',
              'nom': 'PRINCEPS B',
              'cis_code': 'CIS_PRINCEPS_B',
            },
            {
              'code_cip': 'GENERIC_B_CIP',
              'nom': 'GENERIC B1',
              'cis_code': 'CIS_GENERIC_B',
            },
          ],
          principes: [
            {'code_cip': 'PRINCEPS_A_CIP', 'principe': 'PARACETAMOL'},
            {'code_cip': 'GENERIC_A_CIP', 'principe': 'PARACETAMOL'},
            // WHY: GROUP_B must have PARACETAMOL (shared) PLUS an additional ingredient to be a related therapy
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

        final classificationDto = await dbService.classifyProductGroup(
          'GROUP_A',
        );
        final classification = classificationDto?.toDomain();

        expect(classification!.princeps.length, 1);
        expect(classification.relatedPrinceps.length, 1);
        final relatedBucket = classification.relatedPrinceps.first;
        expect(relatedBucket.medicaments.first.codeCip, 'PRINCEPS_B_CIP');
        expect(
          relatedBucket.medicaments.first.principesActifs,
          contains('PARACETAMOL'),
        );
      },
    );
  });

  group('classifyProductGroup', () {
    test('returns canonical classification for deterministic group', () async {
      await dbService.insertBatchData(
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
            'nom': 'PARA PRINCEPS 500 mg comprimé',
            'cis_code': 'CIS_PRINCEPS_MAIN',
          },
          {
            'code_cip': 'CIP_GENERIC_A',
            'nom': 'PARA GENERIC 500 mg comprimé',
            'cis_code': 'CIS_GENERIC_A',
          },
          {
            'code_cip': 'CIP_GENERIC_B',
            'nom': 'PARA GENERIC 500 mg, comprimé pelliculé',
            'cis_code': 'CIS_GENERIC_B',
          },
          {
            'code_cip': 'CIP_PRINCEPS_SECOND',
            'nom': 'PARA PRINCEPS B 500 mg comprimé',
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

      final classificationDto = await dbService.classifyProductGroup(
        'GROUP_MAIN',
      );
      final classification = classificationDto?.toDomain();

      // WHY: The parser removes "PRINCEPS" from medication names as it's a qualifier (princeps = original medication),
      // not part of the actual medication brand name. The baseName will be "PARA", not "PARA PRINCEPS".
      expect(classification!.syntheticTitle.contains('PARA'), isTrue);
      expect(classification.commonActiveIngredients, ['PARACETAMOL']);
      expect(classification.distinctDosages, contains('500 mg'));
      expect(classification.distinctFormulations, contains('Comprimé'));
      expect(classification.princeps.length, 1);
      expect(classification.princeps.first.medicaments.length, 1);
      // WHY: The two generics ("PARA GENERIC 500 mg comprimé" and "PARA GENERIC 500 mg, comprimé pelliculé")
      // may be grouped separately if they have different formulations, so we check that generics exist
      expect(classification.generics.length, greaterThanOrEqualTo(1));
      final totalGenericMedicaments = classification.generics.fold<int>(
        0,
        (sum, group) => sum + group.medicaments.length,
      );
      expect(totalGenericMedicaments, 2);
      expect(classification.relatedPrinceps.length, 1);
      expect(
        classification.relatedPrinceps.first.medicaments.first.codeCip,
        'CIP_PRINCEPS_SECOND',
      );
    });

    test('returns null when group has no members', () async {
      final classificationDto = await dbService.classifyProductGroup('MISSING');
      final classification = classificationDto?.toDomain();
      expect(classification, isNull);
    });
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._documentsPath);
  @override
  Future<String?> getApplicationDocumentsPath() async => _documentsPath;

  @override
  Future<String?> getTemporaryPath() async {
    final tempDir = await Directory.systemTemp.createTemp('pharma_scan_tmp_');
    return tempDir.path;
  }

  final String _documentsPath;
}
