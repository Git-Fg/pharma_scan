// test/core/services/triangulation_logic_test.dart
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(
      NativeDatabase.memory(setup: configureAppSQLite),
    );
  });

  tearDown(() async {
    await database.close();
  });

  // Legacy helper functions copied from sanitizer.dart for test purposes only
  // These simulate the old Dart-based aggregation logic that has been superseded by SQL views
  String findCommonPrincepsName(List<String> names) {
    if (names.isEmpty) return 'N/A';

    if (names.length == 1) return names.first;

    final prefixWords = names.first.split(' ');

    for (var i = 1; i < names.length; i++) {
      final currentWords = names[i].split(' ');
      var commonLength = 0;
      while (commonLength < prefixWords.length &&
          commonLength < currentWords.length &&
          prefixWords[commonLength] == currentWords[commonLength]) {
        commonLength++;
      }

      if (commonLength < prefixWords.length) {
        prefixWords.removeRange(commonLength, prefixWords.length);
      }
    }

    if (prefixWords.isEmpty) {
      return names.reduce((a, b) => a.length < b.length ? a : b);
    }

    return prefixWords.join(' ').trim().replaceAll(RegExp(r'[,.]\s*$'), '');
  }

  String deriveSingleMoleculeName(String name) {
    final parts = name.split(' ');
    final stopIndex = parts.indexWhere(
      (part) => double.tryParse(part.replaceAll(',', '.')) != null,
    );

    if (stopIndex != -1) {
      return parts
          .sublist(0, stopIndex)
          .join(' ')
          .replaceAll(RegExp(r'\s*,$'), '');
    }

    return name.split(',').first.trim();
  }

  String deriveGroupTitleFromName(String name) {
    if (name.contains(' + ')) {
      final segments = name.split(' + ');

      final cleanedSegments = segments
          .map((segment) {
            return deriveSingleMoleculeName(segment.trim());
          })
          .where((cleaned) => cleaned.isNotEmpty)
          .toList();

      return cleanedSegments.join(' + ');
    }

    return deriveSingleMoleculeName(name);
  }

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
      var commonPrincipes = <String>{};
      if (groupPrincipes.isNotEmpty) {
        commonPrincipes = Set<String>.from(groupPrincipes.values.first);
        for (final cipPrincipes in groupPrincipes.values) {
          commonPrincipes = commonPrincipes.intersection(cipPrincipes);
        }
      }

      // Sanitize common principles
      final sanitizedPrincipes = commonPrincipes
          .map(sanitizeActivePrinciple)
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
                principesActifsCommuns: sanitizedPrincipes,
                princepsDeReference: princepsDeReference,
                formePharmaceutique: Value(specialite.formePharmaceutique),
                princepsBrandName: princepsDeReference,
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
    await database.databaseDao.insertBatchData(
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
        },
        {'code_cip': 'CIP_G', 'cis_code': 'CIS_GENERIC'},
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

    // WHEN: We fetch group details backed by the SQL view
    final members = await database.libraryDao.getGroupDetails('GROUP_1');

    // THEN: The group data should contain both princeps and generic
    expect(members.length, greaterThanOrEqualTo(2));
    expect(
      members.map((m) => m.principesActifsCommuns),
      everyElement(isNotEmpty),
    );

    // Verify the broken generic member exists and inherits dosage
    final genericMember = members.firstWhere((m) => !m.isPrinceps);
    expect(genericMember.codeCip, 'CIP_G');
    expect(
      genericMember.formattedDosage,
      equals('500 mg'),
      reason: 'Generic should inherit princeps dosage via SQL aggregation',
    );
  });
}
