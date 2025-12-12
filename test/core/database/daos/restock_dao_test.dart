import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';

import '../../../helpers/db_loader.dart';

void main() {
  group('RestockDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('addToRestock inserts then increments quantity', () async {
      final dao = db.restockDao;
      final cip = Cip13.validated('3400934056781');

      await dao.addToRestock(cip);
      var rows = await db.select(db.restockItems).get();
      expect(rows, hasLength(1));
      expect(rows.first.stockCount, 1);

      await dao.addToRestock(cip);
      rows = await db.select(db.restockItems).get();
      expect(rows, hasLength(1));
      expect(rows.first.stockCount, 2);
    });

    test('updateQuantity decrements and deletes at zero', () async {
      final dao = db.restockDao;
      final cip = Cip13.validated('3400934056781');

      await dao.addToRestock(cip); // quantity = 1
      await dao.updateQuantity(cip, -1); // should delete

      final rows = await db.select(db.restockItems).get();
      expect(rows, isEmpty);
    });

    test('updateQuantity keeps zero when allowZero is true', () async {
      final dao = db.restockDao;
      final cip = Cip13.validated('3400934056781');

      await dao.addToRestock(cip); // quantity = 1
      await dao.updateQuantity(cip, -1, allowZero: true); // should reach 0

      final rows = await db.select(db.restockItems).get();
      expect(rows.single.stockCount, 0);
    });

    test(
      'updateQuantity deletes when dropping below zero with allowZero',
      () async {
        final dao = db.restockDao;
        final cip = Cip13.validated('3400934056781');

        await dao.addToRestock(cip); // quantity = 1
        await dao.updateQuantity(cip, -2, allowZero: true); // should delete

        final rows = await db.select(db.restockItems).get();
        expect(rows, isEmpty);
      },
    );

    test('toggleCheck flips isChecked flag', () async {
      final dao = db.restockDao;
      final cip = Cip13.validated('3400934056781');

      await dao.addToRestock(cip);
      var row = await (db.select(
        db.restockItems,
      )..where((tbl) => tbl.cipCode.equals(cip.toString()))).getSingle();
      // Check if item is checked via notes field (JSON)
      final notes = row.notes;
      final isChecked = notes != null && notes.contains('"checked":true');
      expect(isChecked, isFalse);

      await dao.toggleCheck(cip);
      row = await (db.select(
        db.restockItems,
      )..where((tbl) => tbl.cipCode.equals(cip.toString()))).getSingle();
      // Check if item is checked via notes field (JSON)
      final notesAfter = row.notes;
      final isCheckedAfter =
          notesAfter != null && notesAfter.contains('"checked":true');
      expect(isCheckedAfter, isTrue);
    });

    test('clearChecked removes only checked rows', () async {
      final dao = db.restockDao;
      final cip1 = Cip13.validated('3400934056781');
      final cip2 = Cip13.validated('3400934056782');

      await dao.addToRestock(cip1);
      await dao.addToRestock(cip2);

      await dao.toggleCheck(cip1);
      await dao.clearChecked();

      final rows = await db.select(db.restockItems).get();
      expect(rows, hasLength(1));
      expect(rows.first.cipCode, cip2.toString());
    });

    test('addUniqueBox inserts once and blocks duplicate serials', () async {
      final dao = db.restockDao;
      final cip = Cip13.validated('3400934056781');

      final first = await dao.addUniqueBox(
        cip: cip,
        serial: 'SER-A',
        batchNumber: 'LOT-1',
        expiryDate: DateTime.utc(2025, 3, 5),
      );
      expect(first, ScanOutcome.added);

      final scannedRows = await db.select(db.scannedBoxes).get();
      expect(scannedRows, hasLength(1));
      // box_label format: ${cip}_$serial${batchNumber != null ? '_$batchNumber' : ''}
      expect(scannedRows.first.boxLabel, '${cip}_SER-A_LOT-1');

      final restockRows = await db.select(db.restockItems).get();
      expect(restockRows, hasLength(1));
      expect(restockRows.first.stockCount, 1);

      final second = await dao.addUniqueBox(
        cip: cip,
        serial: 'SER-A',
        batchNumber: 'LOT-1',
      );
      expect(second, ScanOutcome.duplicate);

      final restockAfterDup = await db.select(db.restockItems).get();
      expect(restockAfterDup.single.stockCount, 1);
    });

    test('addUniqueBox falls back to counter when serial is missing', () async {
      final dao = db.restockDao;
      final cip = Cip13.validated('3400934056781');

      final outcome = await dao.addUniqueBox(
        cip: cip,
        batchNumber: 'LOT-2',
        expiryDate: DateTime.utc(2025, 4, 15),
      );
      expect(outcome, ScanOutcome.added);

      final restockRows = await db.select(db.restockItems).get();
      expect(restockRows.single.stockCount, 1);

      final scannedRows = await db.select(db.scannedBoxes).get();
      expect(scannedRows, isEmpty);
    });

    test('clearAll removes restock and scanned boxes', () async {
      final dao = db.restockDao;
      final cip = Cip13.validated('3400934056781');

      await dao.addUniqueBox(
        cip: cip,
        serial: 'SER-B',
      );
      await dao.clearAll();

      final restockRows = await db.select(db.restockItems).get();
      final scannedRows = await db.select(db.scannedBoxes).get();

      expect(restockRows, isEmpty);
      expect(scannedRows, isEmpty);
    });

    test('isDuplicate detects existing serial', () async {
      final dao = db.restockDao;
      final cip = Cip13.validated('3400934056781');

      await dao.addUniqueBox(
        cip: cip,
        serial: 'SER-C',
      );

      final dup = await dao.isDuplicate(
        cip: cip.toString(),
        serial: 'SER-C',
      );
      expect(dup, isTrue);

      final notDup = await dao.isDuplicate(
        cip: cip.toString(),
        serial: 'SER-D',
      );
      expect(notDup, isFalse);
    });

    test('forceUpdateQuantity overwrites aggregated quantity', () async {
      final dao = db.restockDao;
      final cip = Cip13.validated('3400934056781');

      await dao.addUniqueBox(
        cip: cip,
        serial: 'SER-E',
      );

      await dao.forceUpdateQuantity(
        cip: cip.toString(),
        newQuantity: 7,
      );

      final rows = await db.select(db.restockItems).get();
      expect(rows.single.stockCount, 7);
    });

    test('forceUpdateQuantity accepts zero without deleting', () async {
      final dao = db.restockDao;
      final cip = Cip13.validated('3400934056781');

      await dao.addToRestock(cip);
      await dao.forceUpdateQuantity(
        cip: cip.toString(),
        newQuantity: 0,
      );

      final rows = await db.select(db.restockItems).get();
      expect(rows.single.stockCount, 0);
    });

    test('watchRestockItems maps form from summary', () async {
      final dao = db.restockDao;
      final cip = Cip13.validated('3400934056781');

      // Insert laboratory first (for FK constraint)
      await db.customInsert(
        'INSERT OR IGNORE INTO laboratories (id, name) VALUES (?, ?)',
        variables: [
          Variable.withInt(1),
          Variable.withString('Test Lab'),
        ],
        updates: {db.laboratories},
      );

      // Insert specialite using raw SQL
      await db.customInsert(
        'INSERT INTO specialites (cis_code, nom_specialite, procedure_type, forme_pharmaceutique, voies_administration, titulaire_id, etat_commercialisation, statut_administratif, conditions_prescription, is_surveillance) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('CIS_X'),
          Variable.withString('X'),
          Variable.withString('proc'),
          Variable.withString('Comprimé'),
          Variable.withString('orale'),
          Variable.withInt(1),
          Variable.withString('ok'),
          Variable.withString('actif'),
          Variable.withString(''),
          Variable.withBool(false),
        ],
        updates: {db.specialites},
      );

      // Insert medicament using raw SQL
      await db.customInsert(
        'INSERT INTO medicaments (code_cip, cis_code, presentation_label, commercialisation_statut, taux_remboursement, prix_public, agrement_collectivites) VALUES (?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(cip.toString()),
          Variable.withString('CIS_X'),
          Variable.withString(''),
          Variable.withString(''),
          Variable.withString(''),
          Variable.withReal(0),
          Variable.withString(''),
        ],
        updates: {db.medicaments},
      );

      // Insert medicament_summary using raw SQL
      await db.customInsert(
        '''
        INSERT INTO medicament_summary (
          cis_code, nom_canonique, princeps_de_reference, is_princeps,
          group_id, member_type, principes_actifs_communs, forme_pharmaceutique,
          voies_administration, princeps_brand_name, procedure_type, titulaire_id,
          is_surveillance, is_dental, is_list1, is_list2, is_narcotic, is_exception,
          is_restricted, is_otc
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        variables: [
          Variable.withString('CIS_X'),
          Variable.withString('Label'),
          Variable.withString('Princeps'),
          Variable.withBool(true),
          Variable.withString('G'),
          Variable.withInt(0),
          Variable.withString('[]'),
          Variable.withString('Comprimé'),
          Variable.withString('Orale'),
          Variable.withString('Brand'),
          Variable.withString('proc'),
          Variable.withInt(1),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(false),
          Variable.withBool(true),
        ],
        updates: {db.medicamentSummary},
      );
      await dao.addToRestock(cip);

      final items = await dao.watchRestockItems().first;
      expect(items.single.form, 'Comprimé');
    });

    test('watchRestockItems falls back to specialites form', () async {
      final dao = db.restockDao;
      final cip = Cip13.validated('3400934056782');

      // Insert laboratory first (for FK constraint)
      await db.customInsert(
        'INSERT OR IGNORE INTO laboratories (id, name) VALUES (?, ?)',
        variables: [
          Variable.withInt(1),
          Variable.withString('Test Lab'),
        ],
        updates: {db.laboratories},
      );

      // Insert specialite using raw SQL
      await db.customInsert(
        'INSERT INTO specialites (cis_code, nom_specialite, procedure_type, forme_pharmaceutique, voies_administration, titulaire_id, etat_commercialisation, statut_administratif, conditions_prescription, is_surveillance) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('CIS_Y'),
          Variable.withString('Y'),
          Variable.withString('proc'),
          Variable.withString('Sirop'),
          Variable.withString('orale'),
          Variable.withInt(1),
          Variable.withString('ok'),
          Variable.withString('actif'),
          Variable.withString(''),
          Variable.withBool(false),
        ],
        updates: {db.specialites},
      );

      // Insert medicament using raw SQL
      await db.customInsert(
        'INSERT INTO medicaments (code_cip, cis_code, presentation_label, commercialisation_statut, taux_remboursement, prix_public, agrement_collectivites) VALUES (?, ?, ?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(cip.toString()),
          Variable.withString('CIS_Y'),
          Variable.withString(''),
          Variable.withString(''),
          Variable.withString(''),
          Variable.withReal(0),
          Variable.withString(''),
        ],
        updates: {db.medicaments},
      );
      await dao.addToRestock(cip);

      final items = await dao.watchRestockItems().first;
      expect(items.single.form, 'Sirop');
    });

    test('watchScanHistory returns recent scans ordered desc', () async {
      final dao = db.restockDao;
      final cip1 = Cip13.validated('3400934056781');
      final cip2 = Cip13.validated('3400934056782');

      await dao.addUniqueBox(
        cip: cip1,
        serial: 'SER-HIST-1',
        expiryDate: DateTime.utc(2025),
      );
      await dao.addUniqueBox(
        cip: cip2,
        serial: 'SER-HIST-2',
        expiryDate: DateTime.utc(2026),
      );

      await db.customUpdate(
        'UPDATE scanned_boxes SET scan_timestamp = ? WHERE cip_code = ?',
        variables: [
          Variable.withString(DateTime.utc(2024).toIso8601String()),
          Variable.withString(cip1.toString()),
        ],
        updates: {db.scannedBoxes},
      );
      await db.customUpdate(
        'UPDATE scanned_boxes SET scan_timestamp = ? WHERE cip_code = ?',
        variables: [
          Variable.withString(DateTime.utc(2025).toIso8601String()),
          Variable.withString(cip2.toString()),
        ],
        updates: {db.scannedBoxes},
      );

      final history = await dao.watchScanHistory(10).first;
      expect(history, hasLength(2));
      expect(history.first.cip, cip2);
      expect(history.first.isPrinceps, isFalse);
    });

    test('clearHistory deletes only scan journal entries', () async {
      final dao = db.restockDao;
      final cip = Cip13.validated('3400934056781');

      await dao.addUniqueBox(
        cip: cip,
        serial: 'SER-HIST-3',
      );

      expect(await db.select(db.scannedBoxes).get(), isNotEmpty);

      await dao.clearHistory();

      final scannedRows = await db.select(db.scannedBoxes).get();
      expect(scannedRows, isEmpty);
    });
  });
}
