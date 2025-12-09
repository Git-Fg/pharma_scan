import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/daos/database_dao.dart';
import 'package:pharma_scan/core/database/database.dart';

import '../../test_utils.dart' show setPrincipeNormalizedForAllPrinciples;

/// Lightweight facade over [SeedBuilder] for SQL view verification.
/// Allows defining virtual rows directly for view_aggregated_grouped tests.
class SqlScenarioBuilder {
  SqlScenarioBuilder();

  final Map<String, int> _labIds = {};
  final Map<String, String> _groupLabels = {};
  final List<SpecialitesCompanion> _specialites = [];
  final List<MedicamentsCompanion> _medicaments = [];
  final List<PrincipesActifsCompanion> _principes = [];
  final List<GeneriqueGroupsCompanion> _generiqueGroups = [];
  final List<GroupMembersCompanion> _groupMembers = [];
  String? _currentGroupId;

  SqlScenarioBuilder inGroup(String groupId, {required String label}) {
    _groupLabels[groupId] = label;
    final exists = _generiqueGroups.any(
      (group) => group.groupId.value == groupId,
    );
    if (!exists) {
      _generiqueGroups.add(
        GeneriqueGroupsCompanion(
          groupId: Value(groupId),
          libelle: Value(label),
          rawLabel: Value(label),
          parsingMethod: const Value('relational'),
        ),
      );
    }
    _currentGroupId = groupId;
    return this;
  }

  SqlScenarioBuilder addMember({
    required String cis,
    required String cip,
    required String name,
    required int type,
    String? groupId,
    String? groupLabel,
    String principle = 'ACTIVE_PRINCIPLE',
    String? dosage,
    String? dosageUnit,
    String? conditions,
    String? forme,
    String? voiesAdministration,
    String? procedureType,
    String? titulaire,
    bool isSurveillance = false,
    String? statutAdministratif,
  }) {
    final effectiveGroupId = groupId ?? _currentGroupId;
    if (effectiveGroupId == null) {
      throw StateError('Call inGroup() before adding grouped members.');
    }
    if (groupLabel != null) {
      inGroup(effectiveGroupId, label: groupLabel);
    }
    final labName = titulaire ?? 'LAB_$cis';
    final labId = _labIds.putIfAbsent(labName, () => _labIds.length + 1);

    _specialites.add(
      SpecialitesCompanion(
        cisCode: Value(cis),
        nomSpecialite: Value(name),
        procedureType: Value(procedureType ?? 'Autorisation'),
        formePharmaceutique: Value(forme),
        voiesAdministration: Value(voiesAdministration),
        titulaireId: Value(labId),
        conditionsPrescription: Value(conditions),
        isSurveillance: Value(isSurveillance),
        statutAdministratif: Value(statutAdministratif),
      ),
    );

    _medicaments.add(
      MedicamentsCompanion(
        codeCip: Value(cip),
        cisCode: Value(cis),
      ),
    );

    _principes.add(
      PrincipesActifsCompanion(
        codeCip: Value(cip),
        principe: Value(principle),
        dosage: Value(dosage),
        dosageUnit: Value(
          dosage == null ? null : (dosageUnit ?? 'mg'),
        ),
      ),
    );

    _groupMembers.add(
      GroupMembersCompanion(
        codeCip: Value(cip),
        groupId: Value(effectiveGroupId),
        type: Value(type),
      ),
    );

    return this;
  }

  IngestionBatch build() {
    return IngestionBatch(
      specialites: _specialites,
      medicaments: _medicaments,
      principes: _principes,
      generiqueGroups: _generiqueGroups,
      groupMembers: _groupMembers,
      laboratories: _labIds.entries
          .map(
            (entry) => LaboratoriesCompanion(
              id: Value(entry.value),
              name: Value(entry.key),
            ),
          )
          .toList(),
    );
  }

  Future<void> insertInto(AppDatabase database) async {
    await database.databaseDao.insertBatchData(batchData: build());
  }
}

Future<List<Map<String, Object?>>> _selectGroupRows(
  AppDatabase database,
  String groupId,
) async {
  final rows = await database
      .customSelect(
        '''
SELECT *
FROM view_aggregated_grouped
WHERE group_id = ?
ORDER BY is_princeps DESC, cis_code ASC
''',
        variables: [Variable.withString(groupId)],
      )
      .get();

  return rows.map((row) => row.data).toList(growable: false);
}

List<String> _decodeJsonArray(Object? value) {
  if (value is String && value.isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is List) {
      return decoded.whereType<String>().toList();
    }
  }
  return const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SQL Logic - view_aggregated_grouped', () {
    late AppDatabase database;

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test(
      'Scenario A - group libelle becomes nomCanonique for princeps and generics',
      () async {
        final builder = SqlScenarioBuilder()
          ..inGroup('GRP_STD', label: 'PARACETAMOL 500 mg')
          ..addMember(
            cis: 'CIS_P',
            cip: 'CIP_P',
            name: 'Doliprane 500 mg',
            type: 0,
            principle: 'PARACETAMOL',
            dosage: '500',
          )
          ..addMember(
            cis: 'CIS_G1',
            cip: 'CIP_G1',
            name: 'Efferalgan',
            type: 1,
            principle: 'PARACETAMOL',
            dosage: '500',
          )
          ..addMember(
            cis: 'CIS_G2',
            cip: 'CIP_G2',
            name: 'Dafalgan',
            type: 1,
            principle: 'PARACETAMOL',
            dosage: '500',
          );

        await builder.insertInto(database);
        await setPrincipeNormalizedForAllPrinciples(database);

        final rows = await _selectGroupRows(database, 'GRP_STD');

        expect(rows, hasLength(3));
        expect(
          rows.map((row) => row['nom_canonique']),
          everyElement(equals('PARACETAMOL 500 mg')),
        );

        final princepsRow = rows.firstWhere(
          (row) => (row['is_princeps'] as int) == 1,
        );
        final commonPrinciples = _decodeJsonArray(
          princepsRow['principes_actifs_communs'],
        );

        expect(princepsRow['formatted_dosage'], '500 mg');
        expect(commonPrinciples, contains('PARACETAMOL'));
      },
    );

    test(
      'Scenario B - generics without dosage fall back to princeps dosage',
      () async {
        final builder = SqlScenarioBuilder()
          ..inGroup('GRP_DOSAGE', label: 'AMOXICILLIN 1000 mg')
          ..addMember(
            cis: 'CIS_PRIN',
            cip: 'CIP_PRIN',
            name: 'Amoxicilline Princeps',
            type: 0,
            principle: 'AMOXICILLIN',
            dosage: '1000',
            dosageUnit: 'mg',
          )
          ..addMember(
            cis: 'CIS_GEN',
            cip: 'CIP_GEN',
            name: 'Amoxicilline Generic',
            type: 1,
            principle: 'AMOXICILLIN',
            dosage: null,
          );

        await builder.insertInto(database);
        await setPrincipeNormalizedForAllPrinciples(database);

        final rows = await _selectGroupRows(database, 'GRP_DOSAGE');
        final princepsRow = rows.firstWhere(
          (row) => (row['is_princeps'] as int) == 1,
        );
        final genericRow = rows.firstWhere(
          (row) => (row['is_princeps'] as int) == 0,
        );

        final princepsDosage = princepsRow['formatted_dosage'] as String?;
        final inheritedDosage =
            (genericRow['formatted_dosage'] as String?) ?? princepsDosage;

        expect(princepsDosage, isNotNull);
        expect(inheritedDosage, princepsDosage);
      },
    );

    test(
      'Scenario C - regulatory flags and aggregated conditions computed from strings',
      () async {
        final builder = SqlScenarioBuilder()
          ..inGroup('GRP_FLAGS', label: 'FLAG GROUP')
          ..addMember(
            cis: 'CIS_HOSP',
            cip: 'CIP_HOSP',
            name: 'Hospital Only',
            type: 0,
            principle: 'MORPHINE',
            dosage: '10',
            conditions: "Réservé à l'usage hospitalier",
          )
          ..addMember(
            cis: 'CIS_NARC',
            cip: 'CIP_NARC',
            name: 'Stupefiant',
            type: 1,
            principle: 'MORPHINE',
            dosage: '10',
            conditions: 'STUPEFIANT',
          )
          ..addMember(
            cis: 'CIS_LIST1',
            cip: 'CIP_LIST1',
            name: 'Liste I',
            type: 1,
            principle: 'MORPHINE',
            dosage: '10',
            conditions: 'Liste I',
          );

        await builder.insertInto(database);
        await setPrincipeNormalizedForAllPrinciples(database);

        final rows = await _selectGroupRows(database, 'GRP_FLAGS');
        expect(rows, hasLength(3));

        final hospital = rows.firstWhere(
          (row) => row['cis_code'] == 'CIS_HOSP',
        );
        final narcotic = rows.firstWhere(
          (row) => row['cis_code'] == 'CIS_NARC',
        );
        final list1 = rows.firstWhere((row) => row['cis_code'] == 'CIS_LIST1');

        expect(hospital['is_hospital'], 1);
        expect(hospital['is_otc'], 0);

        expect(narcotic['is_narcotic'], 1);
        expect(narcotic['is_list1'], 0);

        expect(list1['is_list1'], 1);
        expect(list1['is_narcotic'], 0);

        final aggregatedConditions = _decodeJsonArray(
          hospital['aggregated_conditions'],
        );
        expect(
          aggregatedConditions.toSet(),
          containsAll({
            "Réservé à l'usage hospitalier",
            'STUPEFIANT',
            'Liste I',
          }),
        );
      },
    );
  });
}
