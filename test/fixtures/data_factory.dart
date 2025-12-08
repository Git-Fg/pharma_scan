// test/fixtures/data_factory.dart
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:pharma_scan/core/database/daos/database_dao.dart';
import 'package:pharma_scan/core/database/database.dart';

/// WHY: Centralize creation of integration-test data passed to
/// `DriftDatabaseService.insertBatchData` so tests stay readable and
/// decoupled from the exact database schema.
@immutable
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

  /// Builds the minimal coherent set of rows for a generic group in the
  /// staging tables, ready to be passed to `insertBatchData`.
  static IngestionBatch createGroup({
    required List<GroupMemberDefinition> members,
    String groupId = _defaultGroupId,
    String libelle = 'TEST GROUP',
  }) {
    final specialites = <SpecialitesCompanion>[];
    final medicaments = <MedicamentsCompanion>[];
    final principes = <PrincipesActifsCompanion>[];
    final groupMembers = <GroupMembersCompanion>[];
    final labIds = <String, int>{};

    for (final member in members) {
      final labName = member.titulaire ?? 'LAB_${member.cisCode}';
      labIds.putIfAbsent(labName, () => labIds.length + 1);
      specialites.add(
        SpecialitesCompanion(
          cisCode: Value(member.cisCode),
          nomSpecialite: Value(member.nomSpecialite),
          procedureType: const Value('Autorisation'),
          titulaireId: Value(labIds[labName]),
        ),
      );

      medicaments.add(
        MedicamentsCompanion(
          codeCip: Value(member.codeCip),
          cisCode: Value(member.cisCode),
        ),
      );

      principes.add(
        PrincipesActifsCompanion(
          codeCip: Value(member.codeCip),
          principe: Value(member.molecule),
          dosage: Value(member.dosage),
          dosageUnit: Value(
            member.dosageUnit.isNotEmpty ? member.dosageUnit : null,
          ),
        ),
      );

      groupMembers.add(
        GroupMembersCompanion(
          codeCip: Value(member.codeCip),
          groupId: Value(groupId),
          type: Value(member.type),
        ),
      );
    }

    final generiqueGroups = <GeneriqueGroupsCompanion>[
      GeneriqueGroupsCompanion(
        groupId: Value(groupId),
        libelle: Value(libelle),
        rawLabel: Value(libelle),
        parsingMethod: const Value('relational'),
      ),
    ];

    return IngestionBatch(
      specialites: specialites,
      medicaments: medicaments,
      principes: principes,
      generiqueGroups: generiqueGroups,
      groupMembers: groupMembers,
      laboratories: labIds.entries
          .map(
            (e) => LaboratoriesCompanion(
              id: Value(e.value),
              name: Value(e.key),
            ),
          )
          .toList(),
    );
  }

  /// Convenience factory matching the common “one princeps + one generic”
  /// pattern used in explorer flow tests.
  static IngestionBatch createBasicGroup({
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
  static IngestionBatch createPrincepsOnlyGroup({
    required List<({String cip, String cis, String name, String dosage})>
    princepsDefinitions,
    String groupId = _defaultGroupId,
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
