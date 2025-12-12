import 'package:diacritic/diacritic.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';

import '../../helpers/db_loader.dart';

void main() {
  group('Search engine with FTS5 molecule/brand columns', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: configureAppSQLite,
        ),
      );

      // Insert medicament_summary directly using SQL-first approach
      // P1 - DOLIPRANE (Princeps)
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
          Variable.withString('P1'),
          Variable.withString('DOLIPRANE'),
          Variable.withString('DOLIPRANE'),
          Variable.withBool(true),
          Variable.withString('GRP1'),
          Variable.withInt(0),
          Variable.withString('["PARACETAMOL"]'),
          Variable.withString(''),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(true),
          Variable.withString('DOLIPRANE'),
        ],
        updates: {db.medicamentSummary},
      );

      // G1 - PARACETAMOL MYLAN (Generic)
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
          Variable.withString('G1'),
          Variable.withString('PARACETAMOL MYLAN'),
          Variable.withString('DOLIPRANE'),
          Variable.withBool(false),
          Variable.withString('GRP1'),
          Variable.withInt(1),
          Variable.withString('["PARACETAMOL"]'),
          Variable.withString(''),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(true),
          Variable.withString('DOLIPRANE'),
        ],
        updates: {db.medicamentSummary},
      );

      // H1 - CŒURCALM (Princeps)
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
          Variable.withString('H1'),
          Variable.withString('CŒURCALM'),
          Variable.withString('CŒURCALM'),
          Variable.withBool(true),
          Variable.withString('GRP2'),
          Variable.withInt(0),
          Variable.withString('["CARDIOTONE"]'),
          Variable.withString(''),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(true),
          Variable.withString('CŒURCALM'),
        ],
        updates: {db.medicamentSummary},
      );

      // T1 - L-THYROXINE (Standalone)
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
          Variable.withString('T1'),
          Variable.withString('L-THYROXINE'),
          Variable.withString('L-THYROXINE'),
          Variable.withBool(true),
          Variable.withString(''),
          Variable.withInt(0),
          Variable.withString('["L THYROXINE"]'),
          Variable.withString(''),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(true),
          Variable.withString('L-THYROXINE'),
        ],
        updates: {db.medicamentSummary},
      );

      // Populate FTS5 search_index
      await db.customInsert(
        'INSERT INTO search_index (cis_code, molecule_name, brand_name) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('P1'),
          Variable.withString(normalizeForSearch('DOLIPRANE PARACETAMOL')),
          Variable.withString(normalizeForSearch('DOLIPRANE')),
        ],
        updates: {db.searchIndex},
      );
      await db.customInsert(
        'INSERT INTO search_index (cis_code, molecule_name, brand_name) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('G1'),
          Variable.withString(normalizeForSearch('PARACETAMOL MYLAN')),
          Variable.withString(normalizeForSearch('DOLIPRANE')),
        ],
        updates: {db.searchIndex},
      );
      await db.customInsert(
        'INSERT INTO search_index (cis_code, molecule_name, brand_name) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('H1'),
          Variable.withString(normalizeForSearch('CŒURCALM CARDIOTONE')),
          Variable.withString(normalizeForSearch('CŒURCALM')),
        ],
        updates: {db.searchIndex},
      );
      await db.customInsert(
        'INSERT INTO search_index (cis_code, molecule_name, brand_name) VALUES (?, ?, ?)',
        variables: [
          Variable.withString('T1'),
          Variable.withString(normalizeForSearch('L-THYROXINE')),
          Variable.withString(normalizeForSearch('L-THYROXINE')),
        ],
        updates: {db.searchIndex},
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('search finds brand via brand_name column (e.g., Doli)', () async {
      final results = await db.catalogDao.searchMedicaments(
        NormalizedQuery('Doli'),
      );
      expect(results, isNotEmpty);
      expect(
        results.any(
          (entity) =>
              entity.data.princepsBrandName.toUpperCase() == 'DOLIPRANE',
        ),
        isTrue,
      );
    });

    test(
      'search finds molecule via molecule_name column (e.g., paracetamol)',
      () async {
        final results = await db.catalogDao.searchMedicaments(
          NormalizedQuery('paracetamol'),
        );
        expect(results.length, greaterThanOrEqualTo(2));
        // Verify that results include medications with PARACETAMOL in molecule_name
        // Note: P1 (DOLIPRANE) has "paracetamol" in molecule_name but not in nomCanonique
        // G1 (PARACETAMOL MYLAN) has it in both
        expect(
          results.any(
            (entity) =>
                entity.data.nomCanonique.toUpperCase().contains('PARACETAMOL'),
          ),
          isTrue,
        );
        // Verify G1 is found
        expect(
          results.any(
            (entity) => entity.data.cisCode == 'G1',
          ),
          isTrue,
        );
      },
    );

    test(
      'search normalizes diacritics (Cœurcalm matches COEURCALM)',
      () async {
        final results = await db.catalogDao.searchMedicaments(
          NormalizedQuery.fromString('Cœurcalm'),
        );

        expect(
          results
              .map(
                (entity) =>
                    removeDiacritics(entity.data.nomCanonique).toUpperCase(),
              )
              .any((name) => name.contains('COEURCALM')),
          isTrue,
        );
      },
    );

    test(
      'search handles hyphenated molecule when querying without punctuation',
      () async {
        final results = await db.catalogDao.searchMedicaments(
          NormalizedQuery.fromString('Thyroxine'),
        );

        expect(
          results
              .map(
                (entity) => entity.data.nomCanonique.toUpperCase().replaceAll(
                  RegExp('[^A-Z0-9]'),
                  '',
                ),
              )
              .any((name) => name.contains('LTHYROXINE')),
          isTrue,
        );
      },
    );

    test(
      'search handles ligatures - oeuf finds œuf (unicode61 tokenizer)',
      () async {
        // Insert medicament_summary with ligature using SQL
        await db.customInsert(
          '''
          INSERT INTO medicament_summary (
            cis_code, nom_canonique, princeps_de_reference, is_princeps,
            group_id, member_type, principes_actifs_communs, formatted_dosage,
            is_hospital, is_dental, is_list1, is_list2, is_narcotic,
            is_exception, is_restricted, is_otc, princeps_brand_name,
            voies_administration
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          variables: [
            Variable.withString('L1'),
            Variable.withString('ŒUFPROTECT'),
            Variable.withString('ŒUFPROTECT'),
            Variable.withBool(true),
            Variable.withString(''),
            Variable.withInt(0),
            Variable.withString('["ŒUF EXTRACT"]'),
            Variable.withString(''),
            Variable.withBool(false),
            Variable.withBool(false),
            Variable.withBool(false),
            Variable.withBool(false),
            Variable.withBool(false),
            Variable.withBool(false),
            Variable.withBool(false),
            Variable.withBool(true),
            Variable.withString('ŒUFPROTECT'),
            Variable.withString('orale'),
          ],
          updates: {db.medicamentSummary},
        );

        // Insert into FTS5 search_index
        await db.customInsert(
          'INSERT INTO search_index (cis_code, molecule_name, brand_name) VALUES (?, ?, ?)',
          variables: [
            Variable.withString('L1'),
            Variable.withString(normalizeForSearch('ŒUFPROTECT ŒUF EXTRACT')),
            Variable.withString(normalizeForSearch('ŒUFPROTECT')),
          ],
          updates: {db.searchIndex},
        );

        // Test searching with "oeuf" should find "ŒUFPROTECT"
        final results = await db.catalogDao.searchMedicaments(
          NormalizedQuery.fromString('oeuf'),
        );

        expect(results, isNotEmpty);
        expect(
          results.any(
            (entity) => entity.data.nomCanonique.contains('ŒUFPROTECT'),
          ),
          isTrue,
          reason:
              'Searching "oeuf" should find "ŒUFPROTECT" with unicode61 tokenizer',
        );
      },
    );

    test('search is case insensitive - doliprane finds DOLIPRANE', () async {
      final results = await db.catalogDao.searchMedicaments(
        NormalizedQuery.fromString('doliprane'),
      );

      expect(results, isNotEmpty);
      expect(
        results.any(
          (entity) =>
              entity.data.princepsBrandName.toUpperCase() == 'DOLIPRANE',
        ),
        isTrue,
        reason: 'Case insensitive search should work',
      );
    });
  });
}
