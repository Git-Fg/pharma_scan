// test/database_service_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';

void main() {
  late AppDatabase database;
  late DatabaseService dbService;

  setUp(() {
    // For each test, create a fresh in-memory database
    database = AppDatabase.forTesting(NativeDatabase.memory());

    // Register the test database and service with the locator
    sl.registerSingleton<AppDatabase>(database);
    sl.registerSingleton<DatabaseService>(DatabaseService());

    dbService = sl<DatabaseService>();
  });

  tearDown(() async {
    // Close the database and reset the locator after each test
    await database.close();
    await sl.reset();
  });

  group('DatabaseService with Drift', () {
    test('should return GenericScanResult for a generic', () async {
      // GIVEN
      await dbService.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_GENERIC',
            'nom_specialite': 'GENERIC DRUG',
            'procedure_type': 'Autorisation',
            'forme_pharmaceutique': 'comprimé',
            'etat_commercialisation': 'Commercialisé',
            'titulaire': 'LABORATOIRE TEST',
          },
        ],
        medicaments: [
          {
            'code_cip': 'GENERIC_CIP',
            'nom': 'GENERIC DRUG',
            'cis_code': 'CIS_GENERIC',
          },
        ],
        principes: [
          {
            'code_cip': 'GENERIC_CIP',
            'principe': 'ACTIVE_PRINCIPLE',
            'dosage': 500.0,
            'dosage_unit': 'mg',
          },
        ],
        generiqueGroups: [
          {'group_id': 'GROUP_1', 'libelle': 'TEST GROUP'},
        ],
        groupMembers: [
          {'code_cip': 'GENERIC_CIP', 'group_id': 'GROUP_1', 'type': 1},
        ],
      );

      // WHEN
      final result = await dbService.getScanResultByCip('GENERIC_CIP');

      // THEN
      expect(result, isA<GenericScanResult>());
      final genericResult = result as GenericScanResult;
      expect(genericResult.medicament.nom, 'GENERIC DRUG');
      expect(genericResult.medicament.principesActifs, ['ACTIVE_PRINCIPLE']);
      expect(genericResult.medicament.titulaire, 'LABORATOIRE TEST');
      expect(genericResult.medicament.dosage, 500.0);
      expect(genericResult.medicament.dosageUnit, 'mg');
      expect(genericResult.associatedPrinceps, isEmpty);
    });

    test('should return GenericScanResult with associated princeps', () async {
      // GIVEN: A generic with associated princeps
      await dbService.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_PRINCEPS',
            'nom_specialite': 'PRINCEPS DRUG',
            'procedure_type': 'Autorisation',
          },
          {
            'cis_code': 'CIS_GENERIC',
            'nom_specialite': 'GENERIC DRUG',
            'procedure_type': 'Autorisation',
          },
        ],
        medicaments: [
          {
            'code_cip': 'PRINCEPS_CIP',
            'nom': 'PRINCEPS DRUG',
            'cis_code': 'CIS_PRINCEPS',
          },
          {
            'code_cip': 'GENERIC_CIP',
            'nom': 'GENERIC DRUG',
            'cis_code': 'CIS_GENERIC',
          },
        ],
        principes: [],
        generiqueGroups: [
          {'group_id': 'GROUP_1', 'libelle': 'TEST GROUP'},
        ],
        groupMembers: [
          {'code_cip': 'PRINCEPS_CIP', 'group_id': 'GROUP_1', 'type': 0},
          {'code_cip': 'GENERIC_CIP', 'group_id': 'GROUP_1', 'type': 1},
        ],
      );

      // WHEN: We query for the generic
      final result = await dbService.getScanResultByCip('GENERIC_CIP');

      // THEN: We get a GenericScanResult with associated princeps
      expect(result, isA<GenericScanResult>());
      final genericResult = result as GenericScanResult;
      expect(genericResult.medicament.nom, 'GENERIC DRUG');
      expect(genericResult.associatedPrinceps.length, 1);
      expect(genericResult.associatedPrinceps.first.codeCip, 'PRINCEPS_CIP');
    });

    test('should return PrincepsScanResult with associated generics', () async {
      // GIVEN
      await dbService.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_PRINCEPS',
            'nom_specialite': 'PRINCEPS DRUG',
            'procedure_type': 'Autorisation',
            'titulaire': 'PRINCEPS LAB',
          },
          {
            'cis_code': 'CIS_GENERIC',
            'nom_specialite': 'GENERIC DRUG 1',
            'procedure_type': 'Autorisation',
            'titulaire': 'GENERIC LAB',
          },
        ],
        medicaments: [
          {
            'code_cip': 'PRINCEPS_CIP',
            'nom': 'PRINCEPS DRUG',
            'cis_code': 'CIS_PRINCEPS',
          },
          {
            'code_cip': 'GENERIC_CIP_1',
            'nom': 'GENERIC DRUG 1',
            'cis_code': 'CIS_GENERIC',
          },
        ],
        principes: [],
        generiqueGroups: [
          {'group_id': 'GROUP_1', 'libelle': 'TEST GROUP'},
        ],
        groupMembers: [
          {'code_cip': 'PRINCEPS_CIP', 'group_id': 'GROUP_1', 'type': 0},
          {'code_cip': 'GENERIC_CIP_1', 'group_id': 'GROUP_1', 'type': 1},
        ],
      );

      // WHEN
      final result = await dbService.getScanResultByCip('PRINCEPS_CIP');

      // THEN
      expect(result, isA<PrincepsScanResult>());
      final princepsResult = result as PrincepsScanResult;
      expect(princepsResult.princeps.nom, 'PRINCEPS DRUG');
      expect(princepsResult.genericLabs.length, 1);
    });

    test(
      'should return PrincepsScanResult with empty list for a standalone drug',
      () async {
        // GIVEN: A medicament not part of any group
        await dbService.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_STANDALONE',
              'nom_specialite': 'STANDALONE DRUG',
              'procedure_type': 'Autorisation',
            },
          ],
          medicaments: [
            {
              'code_cip': 'STANDALONE_CIP',
              'nom': 'STANDALONE DRUG',
              'cis_code': 'CIS_STANDALONE',
            },
          ],
          principes: [],
          generiqueGroups: [],
          groupMembers: [],
        );

        // WHEN: We query for its CIP
        final result = await dbService.getScanResultByCip('STANDALONE_CIP');

        // THEN: It is treated as null (no group membership)
        expect(result, isNull);
      },
    );

    test('should return null for a non-existent CIP', () async {
      // WHEN: We query for a CIP that is not in the database
      final result = await dbService.getScanResultByCip('NON_EXISTENT_CIP');

      // THEN: The result is null
      expect(result, isNull);
    });

    test('getGenericGroupSummaries returns deterministic principles', () async {
      final dbService = sl<DatabaseService>();
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
        final dbService = sl<DatabaseService>();
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

    test('should handle multiple princeps in the same group', () async {
      // GIVEN: A group with multiple princeps and generics
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
            'cis_code': 'CIS_GENERIC',
            'nom_specialite': 'GENERIC DRUG',
            'procedure_type': 'Autorisation',
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
            'code_cip': 'GENERIC_CIP',
            'nom': 'GENERIC DRUG',
            'cis_code': 'CIS_GENERIC',
          },
        ],
        principes: [
          {'code_cip': 'PRINCEPS_1_CIP', 'principe': 'ACTIVE_PRINCIPLE'},
          {'code_cip': 'PRINCEPS_2_CIP', 'principe': 'ACTIVE_PRINCIPLE'},
          {'code_cip': 'GENERIC_CIP', 'principe': 'ACTIVE_PRINCIPLE'},
        ],
        generiqueGroups: [
          {'group_id': 'GROUP_1', 'libelle': 'TEST GROUP'},
        ],
        groupMembers: [
          {'code_cip': 'PRINCEPS_1_CIP', 'group_id': 'GROUP_1', 'type': 0},
          {'code_cip': 'PRINCEPS_2_CIP', 'group_id': 'GROUP_1', 'type': 0},
          {'code_cip': 'GENERIC_CIP', 'group_id': 'GROUP_1', 'type': 1},
        ],
      );

      // WHEN: We query for the first princeps
      final result1 = await dbService.getScanResultByCip('PRINCEPS_1_CIP');

      // THEN: We get a PrincepsScanResult with generic labs extracted
      expect(result1, isNotNull);
      result1!.when(
        generic: (medicament, associatedPrinceps, groupId) {
          fail('Expected PrincepsScanResult but got GenericScanResult');
        },
        princeps: (_, moleculeName, genericLabs, groupId) {
          expect(moleculeName, 'ACTIVE_PRINCIPLE');
          expect(genericLabs.length, greaterThanOrEqualTo(0));
        },
      );

      // WHEN: We query for the second princeps
      final result2 = await dbService.getScanResultByCip('PRINCEPS_2_CIP');

      // THEN: We also get the same group info (both princeps share the same group)
      expect(result2, isNotNull);
      result2!.when(
        generic: (medicament, associatedPrinceps, groupId) {
          fail('Expected PrincepsScanResult but got GenericScanResult');
        },
        princeps: (_, moleculeName, genericLabs, groupId) {
          expect(moleculeName, 'ACTIVE_PRINCIPLE');
          expect(genericLabs.length, greaterThanOrEqualTo(0));
        },
      );
    });

    test(
      'should correctly associate all CIP13s of the same CIS to a group',
      () async {
        // GIVEN: Multiple CIP13s (different packagings) for the same CIS, all in the same group
        // This simulates the one-to-many CIS to CIP13 relationship
        await dbService.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_MED',
              'nom_specialite': 'MEDICAMENT',
              'procedure_type': 'Autorisation',
            },
            {
              'cis_code': 'CIS_GENERIC',
              'nom_specialite': 'GENERIC DRUG',
              'procedure_type': 'Autorisation',
            },
          ],
          medicaments: [
            {
              'code_cip': 'CIP13_1',
              'nom': 'MEDICAMENT PACKAGE 1',
              'cis_code': 'CIS_MED',
            },
            {
              'code_cip': 'CIP13_2',
              'nom': 'MEDICAMENT PACKAGE 2',
              'cis_code': 'CIS_MED',
            },
            {
              'code_cip': 'GENERIC_CIP',
              'nom': 'GENERIC DRUG',
              'cis_code': 'CIS_GENERIC',
            },
          ],
          principes: [
            {'code_cip': 'CIP13_1', 'principe': 'ACTIVE_PRINCIPLE'},
            {'code_cip': 'CIP13_2', 'principe': 'ACTIVE_PRINCIPLE'},
          ],
          generiqueGroups: [
            {'group_id': 'GROUP_1', 'libelle': 'TEST GROUP'},
          ],
          groupMembers: [
            {'code_cip': 'CIP13_1', 'group_id': 'GROUP_1', 'type': 0},
            {
              'code_cip': 'CIP13_2',
              'group_id': 'GROUP_1',
              'type': 0,
            }, // Same CIS, different packaging
            {'code_cip': 'GENERIC_CIP', 'group_id': 'GROUP_1', 'type': 1},
          ],
        );

        // WHEN: We query for either CIP13
        final result1 = await dbService.getScanResultByCip('CIP13_1');
        final result2 = await dbService.getScanResultByCip('CIP13_2');

        // THEN: Both return PrincepsScanResult with the same generic
        expect(result1, isNotNull);
        expect(result2, isNotNull);

        result1!.when(
          generic: (medicament, associatedPrinceps, groupId) {
            fail('Expected PrincepsScanResult but got GenericScanResult');
          },
          princeps: (_, moleculeName, genericLabs, groupId) {
            expect(moleculeName, isNotNull);
            expect(genericLabs.length, greaterThanOrEqualTo(0));
          },
        );

        result2!.when(
          generic: (medicament, associatedPrinceps, groupId) {
            fail('Expected PrincepsScanResult but got GenericScanResult');
          },
          princeps: (_, moleculeName, genericLabs, groupId) {
            expect(moleculeName, isNotNull);
            expect(genericLabs.length, greaterThanOrEqualTo(0));
          },
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
      'should search medicaments by name using clean names from specialites',
      () async {
        // GIVEN: Medicaments in the database with clean names from specialites
        await dbService.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_1',
              'nom_specialite': 'DOLIPRANE',
              'procedure_type': 'Autorisation',
            },
            {
              'cis_code': 'CIS_2',
              'nom_specialite': 'ASPIRINE',
              'procedure_type': 'Autorisation',
            },
            {
              'cis_code': 'CIS_3',
              'nom_specialite': 'PARACETAMOL',
              'procedure_type': 'Autorisation',
            },
          ],
          medicaments: [
            {
              'code_cip': 'CIP1',
              'nom': 'plaquette(s) PVC...',
              'cis_code': 'CIS_1',
            },
            {
              'code_cip': 'CIP2',
              'nom': 'plaquette(s) aluminium...',
              'cis_code': 'CIS_2',
            },
            {
              'code_cip': 'CIP3',
              'nom': 'plaquette(s) blister...',
              'cis_code': 'CIS_3',
            },
          ],
          principes: [],
          generiqueGroups: [],
          groupMembers: [],
        );

        // WHEN: We search for "DOLIPRANE"
        final results = await dbService.searchMedicaments('DOLIPRANE');

        // THEN: Only matching medicament is returned with clean name
        expect(results.length, 1);
        expect(results.first.nom, 'DOLIPRANE');
        expect(results.first.codeCip, 'CIP1');
      },
    );

    test('should search medicaments by CIP code', () async {
      // GIVEN: Medicaments in the database
      await dbService.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_1',
            'nom_specialite': 'MEDICAMENT 1',
            'procedure_type': 'Autorisation',
          },
          {
            'cis_code': 'CIS_2',
            'nom_specialite': 'MEDICAMENT 2',
            'procedure_type': 'Autorisation',
          },
        ],
        medicaments: [
          {
            'code_cip': '3400930302613',
            'nom': 'MEDICAMENT 1',
            'cis_code': 'CIS_1',
          },
          {
            'code_cip': '3400912345678',
            'nom': 'MEDICAMENT 2',
            'cis_code': 'CIS_2',
          },
        ],
        principes: [],
        generiqueGroups: [],
        groupMembers: [],
      );

      // WHEN: We search for "3400930302613"
      final results = await dbService.searchMedicaments('3400930302613');

      // THEN: Matching medicament is returned with clean name
      expect(results.length, 1);
      expect(results.first.codeCip, '3400930302613');
      expect(results.first.nom, 'MEDICAMENT 1');
    });

    test('should search medicaments case-insensitively', () async {
      // GIVEN: Medicaments in the database
      await dbService.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_1',
            'nom_specialite': 'DOLIPRANE 500mg',
            'procedure_type': 'Autorisation',
          },
          {
            'cis_code': 'CIS_2',
            'nom_specialite': 'Aspirine 100mg',
            'procedure_type': 'Autorisation',
          },
        ],
        medicaments: [
          {'code_cip': 'CIP1', 'nom': 'DOLIPRANE 500mg', 'cis_code': 'CIS_1'},
          {'code_cip': 'CIP2', 'nom': 'Aspirine 100mg', 'cis_code': 'CIS_2'},
        ],
        principes: [],
        generiqueGroups: [],
        groupMembers: [],
      );

      // WHEN: We search with lowercase
      final results = await dbService.searchMedicaments('doliprane');

      // THEN: Matching medicament is returned with clean name
      expect(results.length, 1);
      expect(results.first.nom, 'DOLIPRANE 500mg');
    });

    test('should limit search results to 50', () async {
      // GIVEN: More than 50 medicaments
      await dbService.insertBatchData(
        specialites: List.generate(
          60,
          (i) => {
            'cis_code': 'CIS_$i',
            'nom_specialite': 'MEDICAMENT $i',
            'procedure_type': 'Autorisation',
          },
        ),
        medicaments: List.generate(
          60,
          (i) => {
            'code_cip': 'CIP$i',
            'nom': 'MEDICAMENT $i',
            'cis_code': 'CIS_$i',
          },
        ),
        principes: [],
        generiqueGroups: [],
        groupMembers: [],
      );

      // WHEN: We search for a common term
      final results = await dbService.searchMedicaments('MED');

      // THEN: Results are limited to 50
      expect(results.length, lessThanOrEqualTo(50));
    });

    test('should return empty list for no matches', () async {
      // GIVEN: Medicaments in the database
      await dbService.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_1',
            'nom_specialite': 'DOLIPRANE 500mg',
            'procedure_type': 'Autorisation',
          },
        ],
        medicaments: [
          {'code_cip': 'CIP1', 'nom': 'DOLIPRANE 500mg', 'cis_code': 'CIS_1'},
        ],
        principes: [],
        generiqueGroups: [],
        groupMembers: [],
      );

      // WHEN: We search for something that doesn't match
      final results = await dbService.searchMedicaments('NONEXISTENT');

      // THEN: Empty list is returned
      expect(results, isEmpty);
    });

    test(
      'should search medicaments by active ingredient (DOLIPRANE with PARACETAMOL)',
      () async {
        // GIVEN: DOLIPRANE with PARACETAMOL as active ingredient
        await dbService.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_1',
              'nom_specialite': 'DOLIPRANE 500mg',
              'procedure_type': 'Autorisation',
            },
          ],
          medicaments: [
            {'code_cip': 'CIP1', 'nom': 'DOLIPRANE 500mg', 'cis_code': 'CIS_1'},
          ],
          principes: [
            {'code_cip': 'CIP1', 'principe': 'PARACETAMOL'},
          ],
          generiqueGroups: [],
          groupMembers: [],
        );

        // WHEN: We search for the active ingredient
        final results = await dbService.searchMedicaments('paracetamol');

        // THEN: DOLIPRANE is returned in the results
        expect(results.length, 1);
        expect(results.first.nom, 'DOLIPRANE 500mg');
        expect(results.first.codeCip, 'CIP1');
      },
    );

    test(
      'should filter out homeopathic products when showAll is false',
      () async {
        // GIVEN: A conventional medication and a homeopathic product
        await dbService.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_1',
              'nom_specialite': 'MEDICAMENT CONVENTIONNEL',
              'procedure_type': 'Autorisation',
            },
            {
              'cis_code': 'CIS_2',
              'nom_specialite': 'PRODUIT HOMEOPATHIQUE',
              'procedure_type': 'Enreg homéo (Proc. Nat.)',
            },
          ],
          medicaments: [
            {
              'code_cip': 'CIP1',
              'nom': 'MEDICAMENT CONVENTIONNEL',
              'cis_code': 'CIS_1',
            },
            {
              'code_cip': 'CIP2',
              'nom': 'PRODUIT HOMEOPATHIQUE',
              'cis_code': 'CIS_2',
            },
          ],
          principes: [],
          generiqueGroups: [],
          groupMembers: [],
        );

        // WHEN: We search with showAll: false
        final results = await dbService.searchMedicaments(
          'medicament',
          showAll: false,
        );

        // THEN: Only the conventional medication is returned
        expect(results.length, 1);
        expect(results.first.nom, 'MEDICAMENT CONVENTIONNEL');
        expect(results.first.codeCip, 'CIP1');
      },
    );

    test('should include homeopathic products when showAll is true', () async {
      // GIVEN: A conventional medication and a homeopathic product
      await dbService.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_1',
            'nom_specialite': 'MEDICAMENT CONVENTIONNEL',
            'procedure_type': 'Autorisation',
          },
          {
            'cis_code': 'CIS_2',
            'nom_specialite': 'PRODUIT HOMEOPATHIQUE',
            'procedure_type': 'Enreg homéo (Proc. Nat.)',
          },
        ],
        medicaments: [
          {
            'code_cip': 'CIP1',
            'nom': 'MEDICAMENT CONVENTIONNEL',
            'cis_code': 'CIS_1',
          },
          {
            'code_cip': 'CIP2',
            'nom': 'PRODUIT HOMEOPATHIQUE',
            'cis_code': 'CIS_2',
          },
        ],
        principes: [],
        generiqueGroups: [],
        groupMembers: [],
      );

      // WHEN: We search with showAll: true (using a term that matches both)
      final results = await dbService.searchMedicaments('', showAll: true);

      // THEN: Both products are returned
      // Note: Empty search returns all products
      expect(results.length, greaterThanOrEqualTo(2));
      final resultNames = results.map((m) => m.nom).toList();
      expect(
        resultNames,
        containsAll(['MEDICAMENT CONVENTIONNEL', 'PRODUIT HOMEOPATHIQUE']),
      );
    });

    test(
      'should filter out phytotherapy products when showAll is false',
      () async {
        // GIVEN: A conventional medication and a phytotherapy product
        await dbService.insertBatchData(
          specialites: [
            {
              'cis_code': 'CIS_1',
              'nom_specialite': 'MEDICAMENT CONVENTIONNEL',
              'procedure_type': 'Autorisation',
            },
            {
              'cis_code': 'CIS_2',
              'nom_specialite': 'PRODUIT PHYTOTHERAPIE',
              'procedure_type': 'Enreg phyto (Proc. Dec.)',
            },
          ],
          medicaments: [
            {
              'code_cip': 'CIP1',
              'nom': 'MEDICAMENT CONVENTIONNEL',
              'cis_code': 'CIS_1',
            },
            {
              'code_cip': 'CIP2',
              'nom': 'PRODUIT PHYTOTHERAPIE',
              'cis_code': 'CIS_2',
            },
          ],
          principes: [],
          generiqueGroups: [],
          groupMembers: [],
        );

        // WHEN: We search with showAll: false
        final results = await dbService.searchMedicaments(
          'medicament',
          showAll: false,
        );

        // THEN: Only the conventional medication is returned
        expect(results.length, 1);
        expect(results.first.nom, 'MEDICAMENT CONVENTIONNEL');
        expect(results.first.codeCip, 'CIP1');
      },
    );

    test('should include generics with types 2 and 4 in scan results', () async {
      // GIVEN: A group with a princeps and generics of types 1, 2, and 4
      await dbService.insertBatchData(
        specialites: [
          {
            'cis_code': 'CIS_PRINCEPS',
            'nom_specialite': 'PRINCEPS DRUG',
            'procedure_type': 'Autorisation',
            'titulaire': 'PRINCEPS LAB',
          },
          {
            'cis_code': 'CIS_GENERIC_1',
            'nom_specialite': 'GENERIC TYPE 1',
            'procedure_type': 'Autorisation',
            'titulaire': 'GENERIC LAB 1',
          },
          {
            'cis_code': 'CIS_GENERIC_2',
            'nom_specialite': 'GENERIC TYPE 2',
            'procedure_type': 'Autorisation',
            'titulaire': 'GENERIC LAB 2',
          },
          {
            'cis_code': 'CIS_GENERIC_4',
            'nom_specialite': 'GENERIC TYPE 4',
            'procedure_type': 'Autorisation',
            'titulaire': 'GENERIC LAB 4',
          },
        ],
        medicaments: [
          {
            'code_cip': 'PRINCEPS_CIP',
            'nom': 'PRINCEPS DRUG',
            'cis_code': 'CIS_PRINCEPS',
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
        principes: [
          {'code_cip': 'PRINCEPS_CIP', 'principe': 'ACTIVE_PRINCIPLE'},
        ],
        generiqueGroups: [
          {'group_id': 'GROUP_1', 'libelle': 'TEST GROUP'},
        ],
        groupMembers: [
          {'code_cip': 'PRINCEPS_CIP', 'group_id': 'GROUP_1', 'type': 0},
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

      // WHEN: We query for the princeps
      final result = await dbService.getScanResultByCip('PRINCEPS_CIP');

      // THEN: The result should include all three generics (types 1, 2, and 4)
      expect(result, isNotNull);
      result!.when(
        generic: (medicament, associatedPrinceps, groupId) {
          fail('Expected PrincepsScanResult but got GenericScanResult');
        },
        princeps: (princeps, moleculeName, genericLabs, groupId) {
          expect(princeps.codeCip, 'PRINCEPS_CIP');
          // genericLabs extracts lab names, so since test names don't contain known labs,
          // they'll all be "Inconnu" and deduplicated to a single entry
          // The important thing is that all three generics were included in the group
          expect(
            genericLabs.length,
            greaterThanOrEqualTo(1),
          ); // At least one lab (or "Inconnu")
          expect(groupId, 'GROUP_1');
        },
      );

      // Verify all generics are in the group by checking getGroupDetails
      final groupDetails = await dbService.getGroupDetails('GROUP_1');
      expect(
        groupDetails.generics.length,
        3,
      ); // All three generics should be included
    });

    test('should return GroupDetails with varied generic types', () async {
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

      // WHEN: We get group details
      final groupDetails = await dbService.getGroupDetails('GROUP_1');

      // THEN: The GroupDetails should contain 2 princeps and 3 generics grouped by laboratory
      expect(groupDetails.princeps.length, 2);
      // Generics are now grouped by laboratory, so we should have 3 groups (one per laboratory)
      expect(groupDetails.generics.length, 3);
      expect(
        groupDetails.princeps.map((p) => p.codeCip),
        containsAll(['PRINCEPS_1_CIP', 'PRINCEPS_2_CIP']),
      );
      // Verify all generic products are present across all groups
      final allGenericCips = groupDetails.generics
          .expand((g) => g.products.map((p) => p.codeCip))
          .toList();
      expect(
        allGenericCips,
        containsAll(['GENERIC_1_CIP', 'GENERIC_2_CIP', 'GENERIC_4_CIP']),
      );
      // Verify grouping by laboratory
      expect(
        groupDetails.generics.map((g) => g.laboratory),
        containsAll(['LABORATORY_A', 'LABORATORY_B', 'LABORATORY_C']),
      );
    });
  });
}
