// test/fixtures/data_factory.dart

import 'package:flutter/foundation.dart';

/// WHY: Centralize creation of integration-test data passed to
/// `DriftDatabaseService.insertBatchData` so tests stay readable and
/// decoupled from the exact database schema.
@immutable
class GroupBatchData {
  const GroupBatchData({
    required this.specialites,
    required this.medicaments,
    required this.principes,
    required this.generiqueGroups,
    required this.groupMembers,
  });

  final List<Map<String, dynamic>> specialites;
  final List<Map<String, dynamic>> medicaments;
  final List<Map<String, dynamic>> principes;
  final List<Map<String, dynamic>> generiqueGroups;
  final List<Map<String, dynamic>> groupMembers;
}

@immutable
class GroupMemberDefinition {
  const GroupMemberDefinition({
    required this.cisCode,
    required this.codeCip,
    required this.nomSpecialite,
    required this.type,
    this.titulaire,
    this.molecule = 'ACTIVE_PRINCIPLE',
    this.dosage,
    this.dosageUnit = 'mg',
  });

  final String cisCode;
  final String codeCip;
  final String nomSpecialite;

  /// 0 for princeps, 1 for generic (matches `group_members.type` semantics).
  final int type;

  final String? titulaire;
  final String molecule;
  final String? dosage;
  final String dosageUnit;
}

class DataFactory {
  static const String _defaultGroupId = 'GROUP_1';

  /// Helper for a single medicament entry to avoid repeating column names.
  static Map<String, dynamic> medicamentEntry({
    required String cip,
    required String cisCode,
    required String name,
  }) {
    return {
      'code_cip': cip,
      'cis_code': cisCode,
    };
  }

  /// Builds the minimal coherent set of rows for a generic group in the
  /// staging tables, ready to be passed to `insertBatchData`.
  static GroupBatchData createGroup({
    required List<GroupMemberDefinition> members, String groupId = _defaultGroupId,
    String libelle = 'TEST GROUP',
  }) {
    final specialites = <Map<String, dynamic>>[];
    final medicaments = <Map<String, dynamic>>[];
    final principes = <Map<String, dynamic>>[];
    final groupMembers = <Map<String, dynamic>>[];

    for (final member in members) {
      specialites.add({
        'cis_code': member.cisCode,
        'nom_specialite': member.nomSpecialite,
        'procedure_type': 'Autorisation',
        'titulaire': member.titulaire,
      });

      medicaments.add(
        medicamentEntry(
          cip: member.codeCip,
          cisCode: member.cisCode,
          name: member.nomSpecialite,
        ),
      );

      principes.add({
        'code_cip': member.codeCip,
        'principe': member.molecule,
        if (member.dosage != null) 'dosage': member.dosage,
        if (member.dosageUnit.isNotEmpty) 'dosage_unit': member.dosageUnit,
      });

      groupMembers.add({
        'code_cip': member.codeCip,
        'group_id': groupId,
        'type': member.type,
      });
    }

    final generiqueGroups = <Map<String, dynamic>>[
      {'group_id': groupId, 'libelle': libelle},
    ];

    return GroupBatchData(
      specialites: specialites,
      medicaments: medicaments,
      principes: principes,
      generiqueGroups: generiqueGroups,
      groupMembers: groupMembers,
    );
  }

  /// Convenience factory matching the common “one princeps + one generic”
  /// pattern used in explorer flow tests.
  static GroupBatchData createBasicGroup({
    String groupId = _defaultGroupId,
    String princepsCip = 'PRINCEPS_CIP',
    String genericCip = 'GENERIC_CIP',
    String princepsCis = 'CIS_PRINCEPS',
    String genericCis = 'CIS_GENERIC',
    String princepsName = 'PRINCEPS DRUG',
    String genericName = 'GENERIC DRUG',
    String princepsLab = 'PRINCEPS LAB',
    String genericLab = 'GENERIC LAB',
    String molecule = 'ACTIVE_PRINCIPLE',
    String dosage = '500',
    String dosageUnit = 'mg',
  }) {
    return createGroup(
      groupId: groupId,
      members: [
        GroupMemberDefinition(
          cisCode: princepsCis,
          codeCip: princepsCip,
          nomSpecialite: princepsName,
          type: 0,
          titulaire: princepsLab,
          molecule: molecule,
          dosage: dosage,
          dosageUnit: dosageUnit,
        ),
        GroupMemberDefinition(
          cisCode: genericCis,
          codeCip: genericCip,
          nomSpecialite: genericName,
          type: 1,
          titulaire: genericLab,
          molecule: molecule,
          dosage: dosage,
          dosageUnit: dosageUnit,
        ),
      ],
    );
  }

  /// Convenience factory for a group containing only princeps entries with
  /// different dosages (used by dosage-bucketing tests).
  static GroupBatchData createPrincepsOnlyGroup({
    required List<({String cip, String cis, String name, String dosage})>
    princepsDefinitions, String groupId = _defaultGroupId,
    String molecule = 'ACTIVE_PRINCIPLE',
  }) {
    final members = princepsDefinitions
        .map(
          (def) => GroupMemberDefinition(
            cisCode: def.cis,
            codeCip: def.cip,
            nomSpecialite: def.name,
            type: 0,
            molecule: molecule,
            dosage: def.dosage,
          ),
        )
        .toList();

    return createGroup(groupId: groupId, members: members);
  }
}
