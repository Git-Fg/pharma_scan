// test/fixtures/seed_builder.dart
import 'dart:async';

import 'package:pharma_scan/core/database/database.dart';

/// WHY: Fluent builder pattern for creating test database seed data.
/// Simplifies test setup by providing a readable API instead of manually constructing Maps.
/// Supports context switching with `inGroup()` to link subsequent drugs to a group.
class SeedBuilder {
  SeedBuilder();

  final List<Map<String, dynamic>> _specialites = [];
  final List<Map<String, dynamic>> _medicaments = [];
  final List<Map<String, dynamic>> _principes = [];
  final List<Map<String, dynamic>> _generiqueGroups = [];
  final List<Map<String, dynamic>> _groupMembers = [];
  String? _currentGroupId;
  int _cisCounter = 1;

  /// WHY: Context switching method to link subsequent drugs to a group.
  /// Creates the group entry and sets it as the current context.
  /// Subsequent calls to `addPrinceps` or `addGeneric` will be added to this group.
  SeedBuilder inGroup(String groupId, String label) {
    // Check if group already exists
    final existingGroup = _generiqueGroups
        .where((g) => g['group_id'] == groupId)
        .isNotEmpty;

    if (!existingGroup) {
      _generiqueGroups.add({'group_id': groupId, 'libelle': label});
    }

    _currentGroupId = groupId;
    // WHY: Fluent builder pattern requires returning this for method chaining
    // ignore: avoid_returning_this
    return this;
  }

  /// WHY: Adds a princeps medication to the current group (or as standalone if no group).
  /// Auto-generates CIS code if not provided.
  SeedBuilder addPrinceps(
    String name,
    String cip, {
    String? cis,
    String? dosage,
    String? form,
    String? lab,
  }) {
    final cisCode = cis ?? _generateCisCode();
    _addMedication(
      name: name,
      cip: cip,
      cisCode: cisCode,
      type: 0, // Princeps
      dosage: dosage,
      form: form,
      lab: lab,
    );
    // WHY: Fluent builder pattern requires returning this for method chaining
    // ignore: avoid_returning_this
    return this;
  }

  /// WHY: Adds a generic medication to the current group (or as standalone if no group).
  /// Auto-generates CIS code if not provided.
  SeedBuilder addGeneric(
    String name,
    String cip, {
    String? cis,
    String? dosage,
    String? form,
    String? lab,
  }) {
    final cisCode = cis ?? _generateCisCode();
    _addMedication(
      name: name,
      cip: cip,
      cisCode: cisCode,
      type: 1, // Generic
      dosage: dosage,
      form: form,
      lab: lab,
    );
    // WHY: Fluent builder pattern requires returning this for method chaining
    // ignore: avoid_returning_this
    return this;
  }

  /// WHY: Internal helper to add a medication with all required entries.
  /// Creates entries in specialites, medicaments, principes, and groupMembers tables.
  void _addMedication({
    required String name,
    required String cip,
    required String cisCode,
    required int type,
    String? dosage,
    String? form,
    String? lab,
  }) {
    // Add specialite entry
    _specialites.add({
      'cis_code': cisCode,
      'nom_specialite': name,
      'procedure_type': 'Autorisation',
      'forme_pharmaceutique': ?form,
      'titulaire': ?lab,
    });

    // Add medicament entry
    _medicaments.add({'code_cip': cip, 'cis_code': cisCode});

    // Add principe entry (default molecule if dosage provided)
    if (dosage != null) {
      _principes.add({
        'code_cip': cip,
        'principe': 'ACTIVE_PRINCIPLE',
        'dosage': dosage,
        'dosage_unit': 'mg',
      });
    } else {
      // Add default principe even without dosage
      _principes.add({'code_cip': cip, 'principe': 'ACTIVE_PRINCIPLE'});
    }

    // Add group member entry if in a group
    if (_currentGroupId != null) {
      _groupMembers.add({
        'code_cip': cip,
        'group_id': _currentGroupId,
        'type': type,
      });
    }
  }

  /// WHY: Generates a unique CIS code for medications that don't provide one.
  /// Uses a counter to ensure uniqueness within the builder instance.
  String _generateCisCode() {
    return 'CIS_${_cisCounter++}';
  }

  /// WHY: Builds the final data structure required by `DriftDatabaseService.insertBatchData`.
  /// Returns a map with all the required keys.
  ///
  /// Usage:
  /// ```dart
  /// final data = SeedBuilder()
  ///   .inGroup('GRP1', 'Doliprane 1000')
  ///   .addPrinceps('Doliprane 1000mg', 'CIP_P')
  ///   .addGeneric('Paracetamol Biogaran', 'CIP_G')
  ///   .build();
  /// await dbService.insertBatchData(
  ///   specialites: data['specialites']!,
  ///   medicaments: data['medicaments']!,
  ///   principes: data['principes']!,
  ///   generiqueGroups: data['generiqueGroups']!,
  ///   groupMembers: data['groupMembers']!,
  /// );
  /// ```
  Map<String, List<Map<String, dynamic>>> build() {
    return {
      'specialites': _specialites,
      'medicaments': _medicaments,
      'principes': _principes,
      'generiqueGroups': _generiqueGroups,
      'groupMembers': _groupMembers,
    };
  }

  /// WHY: Convenience method to directly call insertBatchData with the built data.
  /// This allows for even more concise test setup.
  ///
  /// Usage:
  /// ```dart
  /// await SeedBuilder()
  ///   .inGroup('GRP1', 'Doliprane 1000')
  ///   .addPrinceps('Doliprane 1000mg', 'CIP_P')
  ///   .addGeneric('Paracetamol Biogaran', 'CIP_G')
  ///   .insertInto(database);
  /// ```
  Future<void> insertInto(AppDatabase database) async {
    final data = build();
    await database.databaseDao.insertBatchData(
      specialites: data['specialites']!,
      medicaments: data['medicaments']!,
      principes: data['principes']!,
      generiqueGroups: data['generiqueGroups']!,
      groupMembers: data['groupMembers']!,
    );
  }
}
