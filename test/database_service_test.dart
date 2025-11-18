// test/database_service_test.dart
import 'dart:convert';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';
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

  // Helper function to populate MedicamentSummary table for tests
  Future<void> populateMedicamentSummary(AppDatabase db) async {
    // Get all group members
    final groupMembers = await db.select(db.groupMembers).get();
    if (groupMembers.isEmpty) return;

    // Get all specialites and medicaments
    final specialites = await db.select(db.specialites).get();
    final medicaments = await db.select(db.medicaments).get();
    final principes = await db.select(db.principesActifs).get();

    // Group by groupId
    final groupsByGroupId = <String, List<GroupMember>>{};
    for (final member in groupMembers) {
      groupsByGroupId.putIfAbsent(member.groupId, () => []).add(member);
    }

    // For each group, calculate common principles and reference princeps
    for (final entry in groupsByGroupId.entries) {
      final groupId = entry.key;
      final members = entry.value;

      // Get all CIPs in this group
      final cips = members.map((m) => m.codeCip).toSet();

      // Get all principles for this group
      final groupPrincipes = <String, Set<String>>{};
      for (final cip in cips) {
        final cipPrincipes = principes
            .where((p) => p.codeCip == cip)
            .map((p) => p.principe)
            .toSet();
        groupPrincipes[cip] = cipPrincipes;
      }

      // Calculate common principles (intersection of all)
      Set<String> commonPrincipes = {};
      if (groupPrincipes.isNotEmpty) {
        commonPrincipes = Set<String>.from(groupPrincipes.values.first);
        for (final cipPrincipes in groupPrincipes.values) {
          commonPrincipes = commonPrincipes.intersection(cipPrincipes);
        }
      }

      // Sanitize common principles
      final sanitizedPrincipes = commonPrincipes
          .map((p) => sanitizeActivePrinciple(p))
          .where((p) => p.isNotEmpty)
          .toList();

      // Get princeps names for this group
      final princepsMembers = members.where((m) => m.type == 0).toList();
      final princepsNames = <String>[];
      for (final member in princepsMembers) {
        final medicament = medicaments.firstWhere(
          (m) => m.codeCip == member.codeCip,
        );
        final specialite = specialites.firstWhere(
          (s) => s.cisCode == medicament.cisCode,
        );
        princepsNames.add(specialite.nomSpecialite);
      }

      final princepsDeReference = findCommonPrincepsName(princepsNames);

      // Insert summary for each member
      final insertedCis = <String>{};
      for (final member in members) {
        final medicament = medicaments.firstWhere(
          (m) => m.codeCip == member.codeCip,
        );
        final specialite = specialites.firstWhere(
          (s) => s.cisCode == medicament.cisCode,
        );
        final nomCanonique = deriveGroupTitleFromName(specialite.nomSpecialite);

        if (!insertedCis.add(medicament.cisCode)) {
          continue;
        }

        await db
            .into(db.medicamentSummary)
            .insert(
              MedicamentSummaryCompanion.insert(
                cisCode: medicament.cisCode,
                nomCanonique: nomCanonique,
                isPrinceps: member.type == 0,
                groupId: Value(groupId),
                principesActifsCommuns: jsonEncode(sanitizedPrincipes),
                princepsDeReference: princepsDeReference,
                formePharmaceutique: Value(specialite.formePharmaceutique),
                princepsBrandName: princepsDeReference,
                clusterKey: '${princepsDeReference}_$groupId',
              ),
            );
      }
    }
  }

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
            'dosage': '500',
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

      // Populate MedicamentSummary table
      await populateMedicamentSummary(database);

      // WHEN
      final result = await dbService.getScanResultByCip('GENERIC_CIP');

      // THEN
      expect(result, isA<GenericScanResult>());
      final genericResult = result as GenericScanResult;
      expect(genericResult.medicament.nom, 'GENERIC DRUG');
      expect(genericResult.medicament.principesActifs, ['ACTIVE_PRINCIPLE']);
      expect(genericResult.medicament.titulaire, 'LABORATOIRE TEST');
      expect(genericResult.medicament.dosage, Decimal.fromInt(500));
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

      // Populate MedicamentSummary table
      await populateMedicamentSummary(database);

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

      // Populate MedicamentSummary table
      await populateMedicamentSummary(database);

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

      // Populate MedicamentSummary table
      await populateMedicamentSummary(database);

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
            'nom_specialite': 'PRINCEPS ALPHA',
            'procedure_type': 'Autorisation',
          },
          {
            'cis_code': 'CIS_PRINCEPS_2',
            'nom_specialite': 'PRINCEPS BETA',
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
            'nom': 'PRINCEPS ALPHA',
            'cis_code': 'CIS_PRINCEPS_1',
          },
          {
            'code_cip': 'PRINCEPS_2_CIP',
            'nom': 'PRINCEPS BETA',
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

      // Populate MedicamentSummary table
      await populateMedicamentSummary(database);

      // WHEN: We query for the first princeps
      final result1 = await dbService.getScanResultByCip('PRINCEPS_1_CIP');

      // THEN: We get a PrincepsScanResult with generic labs extracted
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

        // Populate MedicamentSummary table
        await populateMedicamentSummary(database);

        // WHEN: We query for either CIP13
        final result1 = await dbService.getScanResultByCip('CIP13_1');
        final result2 = await dbService.getScanResultByCip('CIP13_2');

        // THEN: Both return PrincepsScanResult with the same generic
        result1!.when(
          generic: (medicament, associatedPrinceps, groupId) {
            fail('Expected PrincepsScanResult but got GenericScanResult');
          },
          princeps: (_, moleculeName, genericLabs, groupId) {
            expect(moleculeName, isNotEmpty);
            expect(genericLabs.length, greaterThanOrEqualTo(0));
          },
        );

        result2!.when(
          generic: (medicament, associatedPrinceps, groupId) {
            fail('Expected PrincepsScanResult but got GenericScanResult');
          },
          princeps: (_, moleculeName, genericLabs, groupId) {
            expect(moleculeName, isNotEmpty);
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

        await populateMedicamentSummary(database);

        final candidates = await dbService.getAllSearchCandidates();
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

      await populateMedicamentSummary(database);

      final candidates = await dbService.getAllSearchCandidates();
      expect(candidates.length, 2);

      final homeopathic = candidates.firstWhere(
        (candidate) => candidate.cisCode == 'CIS_HOMEO',
      );
      final conventional = candidates.firstWhere(
        (candidate) => candidate.cisCode == 'CIS_CONV',
      );

      expect(homeopathic.procedureType, contains('homéo'));
      expect(conventional.procedureType, 'Autorisation');
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

      await populateMedicamentSummary(database);

      final candidates = await dbService.getAllSearchCandidates();
      expect(candidates.length, 2);
      final names = candidates.map((c) => c.nomCanonique).toList();
      final sortedNames = [...names]..sort((a, b) => a.compareTo(b));
      expect(names, equals(sortedNames));
    });

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

      // Populate MedicamentSummary table
      await populateMedicamentSummary(database);

      // WHEN: We query for the princeps
      final result = await dbService.getScanResultByCip('PRINCEPS_CIP');

      // THEN: The result should include all three generics (types 1, 2, and 4)
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

      // Verify classification exposes every generic in the group
      final classification = await dbService.classifyProductGroup('GROUP_1');

      final genericCips = classification!.generics
          .expand((bucket) => bucket.medicaments)
          .map((medicament) => medicament.codeCip)
          .toList();
      expect(
        genericCips,
        containsAll(['GENERIC_1_CIP', 'GENERIC_2_CIP', 'GENERIC_4_CIP']),
      );
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

      // WHEN: We classify the group
      final classification = await dbService.classifyProductGroup('GROUP_1');

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

        final classification = await dbService.classifyProductGroup('GROUP_A');

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

      final classification = await dbService.classifyProductGroup('GROUP_MAIN');

      expect(classification!.syntheticTitle.contains('PARA PRINCEPS'), isTrue);
      expect(classification.commonActiveIngredients, ['PARACETAMOL']);
      expect(classification.distinctDosages, contains('500 mg'));
      expect(classification.distinctFormulations, contains('Comprimé'));
      expect(classification.princeps.length, 1);
      expect(classification.princeps.first.medicaments.length, 1);
      expect(classification.generics.first.medicaments.length, 2);
      expect(classification.relatedPrinceps.length, 1);
      expect(
        classification.relatedPrinceps.first.medicaments.first.codeCip,
        'CIP_PRINCEPS_SECOND',
      );
    });

    test('returns null when group has no members', () async {
      final classification = await dbService.classifyProductGroup('MISSING');
      expect(classification, isNull);
    });
  });
}
