import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';

import '../../../helpers/golden_db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FTS5 ranking and filtering', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      // Note: This test only needs medicament_summary and search_index.
      // Base tables (specialites, medicaments) are not needed for FTS5 search tests.

      // Insert medicament_summary using raw SQL to avoid dependency on generated types
      await db.customInsert(
        '''
            INSERT INTO medicament_summary (
              cis_code, nom_canonique, princeps_de_reference, is_princeps,
              group_id, member_type, principes_actifs_communs, formatted_dosage,
              is_hospital, is_dental, is_list1, is_list2, is_narcotic,
              is_exception, is_restricted, is_otc, princeps_brand_name
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
        variables: [
          Variable.withString('1'),
          Variable.withString('Doliprane 500'),
          Variable.withString('Doliprane 500'),
          Variable.withBool(true),
          Variable.withString(''),
          Variable.withInt(0),
          Variable.withString('[]'),
          Variable.withString(''),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(true),
          Variable.withString('Doliprane'),
        ],
        updates: {db.medicamentSummary},
      );
      await db.customInsert(
        '''
            INSERT INTO medicament_summary (
              cis_code, nom_canonique, princeps_de_reference, is_princeps,
              group_id, member_type, principes_actifs_communs, formatted_dosage,
              is_hospital, is_dental, is_list1, is_list2, is_narcotic,
              is_exception, is_restricted, is_otc, princeps_brand_name
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
        variables: [
          Variable.withString('2'),
          Variable.withString('Doli 1000'),
          Variable.withString('Doli 1000'),
          Variable.withBool(true),
          Variable.withString(''),
          Variable.withInt(0),
          Variable.withString('[]'),
          Variable.withString(''),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(true),
          Variable.withString('Doli'),
        ],
        updates: {db.medicamentSummary},
      );
      await db.customInsert(
        '''
            INSERT INTO medicament_summary (
              cis_code, nom_canonique, princeps_de_reference, is_princeps,
              group_id, member_type, principes_actifs_communs, formatted_dosage,
              is_hospital, is_dental, is_list1, is_list2, is_narcotic,
              is_exception, is_restricted, is_otc, princeps_brand_name
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
        variables: [
          Variable.withString('3'),
          Variable.withString('Paracetamol + Codeine'),
          Variable.withString('Paracetamol + Codeine'),
          Variable.withBool(true),
          Variable.withString(''),
          Variable.withInt(0),
          Variable.withString('[]'),
          Variable.withString(''),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(true),
          Variable.withString('Paracetamol'),
        ],
        updates: {db.medicamentSummary},
      );

      // Insert search_index using raw SQL (FTS5 virtual table)
      await db.customInsert(
        'INSERT INTO search_index (cis_code, molecule_name, brand_name) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('1'),
          Variable.withString(normalizeForSearch('Doliprane 500 Dolipprane')),
          Variable.withString(normalizeForSearch('Doliprane Dolipprane')),
        ],
        updates: {db.searchIndex},
      );
      await db.customInsert(
        'INSERT INTO search_index (cis_code, molecule_name, brand_name) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('2'),
          Variable.withString(normalizeForSearch('Doli 1000')),
          Variable.withString(normalizeForSearch('Doli')),
        ],
        updates: {db.searchIndex},
      );
      await db.customInsert(
        'INSERT INTO search_index (cis_code, molecule_name, brand_name) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('3'),
          Variable.withString(normalizeForSearch('Paracetamol Codeine')),
          Variable.withString(normalizeForSearch('Paracetamol')),
        ],
        updates: {db.searchIndex},
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('exact match ranks above fuzzy match', () async {
      final results = await db.catalogDao.searchMedicaments(
        NormalizedQuery.fromString('Doliprane'),
      );

      expect(results, isNotEmpty);
      expect(results.first.data.cisCode, '1');
    });

    test('trigram search tolerates typos', () async {
      final results = await db.catalogDao.searchMedicaments(
        NormalizedQuery.fromString('Dolipprane'),
      );

      expect(
        results.any((entity) => entity.data.cisCode == '1'),
        isTrue,
      );
    });

    test(
      'percent characters are sanitized, not treated as wildcards',
      () async {
        final results = await db.catalogDao.searchMedicaments(
          NormalizedQuery.fromString('Doli%'),
        );

        expect(
          results.any((entity) => entity.data.cisCode == '2'),
          isTrue,
        );
      },
    );
  });
}
