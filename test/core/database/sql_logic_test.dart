// Test file for external DB-driven architecture - uses dynamic types for backend-provided data

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import '../../helpers/golden_db_helper.dart';

/// Simplified test helper for medicament_summary.
/// In production, medicament_summary is pre-populated by the backend pipeline.
/// These tests verify that the mobile app can read and query it correctly.
Future<void> _insertSummaryRow(
  AppDatabase database, {
  required String cisCode,
  required String nomCanonique,
  required String princepsDeReference,
  required bool isPrinceps,
  String? groupId,
  String principesActifsCommuns = '[]',
  String? formattedDosage,
  int isHospital = 0,
  int isNarcotic = 0,
  int isList1 = 0,
  int isOtc = 1,
  String? aggregatedConditions,
}) async {
  // Use customInsert to avoid dependency on generated companion types
  // For nullable values, use empty string (SQLite will treat as NULL for TEXT columns when appropriate)
  await database.customInsert(
    '''
    INSERT INTO medicament_summary (
      cis_code, nom_canonique, princeps_de_reference, is_princeps,
      group_id, member_type, principes_actifs_communs, formatted_dosage,
      is_hospital, is_narcotic, is_list1, is_otc, aggregated_conditions,
      princeps_brand_name
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
    variables: [
      Variable.withString(cisCode),
      Variable.withString(nomCanonique),
      Variable.withString(princepsDeReference),
      Variable.withBool(isPrinceps),
      Variable.withString(groupId ?? ''),
      Variable.withInt(0),
      Variable.withString(principesActifsCommuns),
      Variable.withString(formattedDosage ?? ''),
      Variable.withBool(isHospital == 1),
      Variable.withBool(isNarcotic == 1),
      Variable.withBool(isList1 == 1),
      Variable.withBool(isOtc == 1),
      Variable.withString(aggregatedConditions ?? ''),
      Variable.withString(princepsDeReference),
    ],
    updates: {database.medicamentSummary},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('medicament_summary - Data Reading & Querying', () {
    late AppDatabase database;

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );
    });

    tearDown(() async {
      await database.close();
    });

    test('can read grouped medications from medicament_summary', () async {
      // GIVEN: medicament_summary populated by backend (simulated in test)
      await _insertSummaryRow(
        database,
        cisCode: 'CIS_P',
        nomCanonique: 'PARACETAMOL 500 mg',
        princepsDeReference: 'PARACETAMOL 500 mg',
        isPrinceps: true,
        groupId: 'GRP_STD',
        principesActifsCommuns: '["PARACETAMOL"]',
        formattedDosage: '500 mg',
      );
      await _insertSummaryRow(
        database,
        cisCode: 'CIS_G1',
        nomCanonique: 'PARACETAMOL 500 mg',
        princepsDeReference: 'PARACETAMOL 500 mg',
        isPrinceps: false,
        groupId: 'GRP_STD',
        principesActifsCommuns: '["PARACETAMOL"]',
        formattedDosage: '500 mg',
      );

      // WHEN: Query by group_id
      final summaries = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.groupId.equals('GRP_STD')))
          .get();

      // THEN: Can read grouped medications
      expect(summaries, hasLength(2));
      expect(
        summaries.map((s) => s.nomCanonique),
        everyElement(equals('PARACETAMOL 500 mg')),
      );
      expect(summaries.any((s) => s.isPrinceps), isTrue);
      expect(summaries.any((s) => !s.isPrinceps), isTrue);
    });

    test('can read regulatory flags from medicament_summary', () async {
      // GIVEN: medicament_summary with regulatory flags (set by backend)
      await _insertSummaryRow(
        database,
        cisCode: 'CIS_HOSP',
        nomCanonique: 'Hospital Only',
        princepsDeReference: 'Hospital Only',
        isPrinceps: true,
        isHospital: 1,
        isOtc: 0,
      );
      await _insertSummaryRow(
        database,
        cisCode: 'CIS_NARC',
        nomCanonique: 'Stupefiant',
        princepsDeReference: 'Stupefiant',
        isPrinceps: true,
        isNarcotic: 1,
        isList1:
            0, // ignore: avoid_redundant_argument_values // Explicitly set to 0 for clarity in test data
      );
      await _insertSummaryRow(
        database,
        cisCode: 'CIS_LIST1',
        nomCanonique: 'Liste I',
        princepsDeReference: 'Liste I',
        isPrinceps: true,
        isList1: 1,
      );

      // WHEN: Query individual medications
      final hospital = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_HOSP')))
          .getSingle();
      final narcotic = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_NARC')))
          .getSingle();
      final list1 = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_LIST1')))
          .getSingle();

      // THEN: Flags are correctly readable
      expect(hospital.isHospital, isTrue);
      expect(hospital.isOtc, isFalse);
      expect(narcotic.isNarcotic, isTrue);
      expect(narcotic.isList1, isFalse);
      expect(list1.isList1, isTrue);
      expect(list1.isNarcotic, isFalse);
    });

    test('can read aggregated conditions from medicament_summary', () async {
      // GIVEN: medicament_summary with aggregated conditions (computed by backend)
      await _insertSummaryRow(
        database,
        cisCode: 'CIS_TEST',
        nomCanonique: 'Test Medication',
        princepsDeReference: 'Test Medication',
        isPrinceps: true,
        aggregatedConditions: '["Condition 1", "Condition 2"]',
      );

      // WHEN: Read the summary
      final summary = await (database.select(
        database.medicamentSummary,
      )..where((tbl) => tbl.cisCode.equals('CIS_TEST')))
          .getSingle();

      // THEN: Aggregated conditions are readable
      expect(summary.aggregatedConditions, isNotNull);
      expect(summary.aggregatedConditions, contains('Condition 1'));
      expect(summary.aggregatedConditions, contains('Condition 2'));
    });
  });
}
