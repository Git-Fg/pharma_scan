// test/core/services/triangulation_logic_test.dart
import 'dart:convert';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';

void main() {
  late AppDatabase database;
  late DatabaseService dbService;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    sl.registerSingleton<AppDatabase>(database);
    dbService = DatabaseService();
  });

  tearDown(() async {
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
                titulaire: Value(specialite.titulaire),
                procedureType: Value(specialite.procedureType),
              ),
            );
      }
    }
  }

  test('Triangulation: Broken generic inherits dosage from Princeps', () async {
    // GIVEN: A group with a clean Princeps and a "messy" Generic
    // The Generic has NO dosage in its name or composition (simulating bad data)
    await dbService.insertBatchData(
      specialites: [
        {
          'cis_code': 'CIS_PRINCEPS',
          'nom_specialite': 'PRINCEPS 500 mg, comprimé',
          'procedure_type': 'Autorisation',
          'forme_pharmaceutique': 'Comprimé',
          'titulaire': 'LABO PRINCEPS',
        },
        {
          'cis_code': 'CIS_GENERIC',
          'nom_specialite': 'GENERIC LABO', // No dosage in name!
          'procedure_type': 'Autorisation',
          'forme_pharmaceutique': 'Comprimé',
          'titulaire': 'LABO GENERIC',
        },
      ],
      medicaments: [
        {
          'code_cip': 'CIP_P',
          'cis_code': 'CIS_PRINCEPS',
          'nom': 'PRINCEPS 500 mg',
        },
        {'code_cip': 'CIP_G', 'cis_code': 'CIS_GENERIC', 'nom': 'GENERIC LABO'},
      ],
      principes: [
        // Princeps has clean dosage
        {
          'code_cip': 'CIP_P',
          'principe': 'MOLECULE',
          'dosage': '500',
          'dosage_unit': 'mg',
        },
        // Generic has MISSING dosage in DB (simulating parsing failure or empty data)
        {
          'code_cip': 'CIP_G',
          'principe': 'MOLECULE',
          'dosage': null,
          'dosage_unit': null,
        },
      ],
      generiqueGroups: [
        {'group_id': 'GROUP_1', 'libelle': 'MOLECULE 500 mg'},
      ],
      groupMembers: [
        {'code_cip': 'CIP_P', 'group_id': 'GROUP_1', 'type': 0}, // Princeps
        {'code_cip': 'CIP_G', 'group_id': 'GROUP_1', 'type': 1}, // Generic
      ],
    );

    // Populate MedicamentSummary table
    await populateMedicamentSummary(database);

    // WHEN: We ask the service to classify the group
    final result = await dbService.classifyProductGroup('GROUP_1');

    // THEN: The "Broken" Generic should be grouped under the Princeps' dosage
    // It should NOT form a separate "N/A" bucket.

    expect(result, isNotNull);

    // We expect 1 bucket for generics (because it merged with the inferred dosage)
    // If logic fails, we might have 2 buckets (one 500mg, one null)
    final genericBuckets = result!.generics;

    // Verify we have a bucket with dosage 500
    final targetBucket = genericBuckets.firstWhere(
      (b) => b.dosage == Decimal.fromInt(500),
      orElse: () => throw Exception('Generic failed to inherit dosage 500mg'),
    );

    // Verify our broken generic is inside
    expect(
      targetBucket.medicaments.any((m) => m.codeCip == 'CIP_G'),
      isTrue,
      reason: 'The broken generic should be grouped into the 500mg bucket',
    );

    // Verify we don't have a separate "N/A" bucket for the broken generic
    final nullBuckets = genericBuckets.where((b) => b.dosage == null).toList();
    expect(
      nullBuckets,
      isEmpty,
      reason:
          'The broken generic should not form a separate null dosage bucket',
    );
  });
}
