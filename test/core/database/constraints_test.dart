import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';

void main() {
  group('Database constraints', () {
    late AppDatabase db;
    late RestockDao dao;

    setUp(() async {
      db = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );
      // Create required tables for this test
      // Note: Tables are already created by migration, but we need specialites for FK
      // Also need to add UNIQUE constraint to scanned_boxes for this test
      await db.customInsert(
        'INSERT OR IGNORE INTO specialites (cis_code, nom_specialite, procedure_type, forme_pharmaceutique, etat_commercialisation) VALUES (?, ?, ?, ?, ?)',
        variables: [
          Variable.withString('CIS_TEST'),
          Variable.withString('Test Specialite'),
          Variable.withString('Autorisation'),
          Variable.withString(''),
          Variable.withString('Commercialisée'),
        ],
        updates: {db.specialites},
      );

      // Add UNIQUE constraint to scanned_boxes for duplicate detection test
      try {
        await db.customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_scanned_boxes_unique ON scanned_boxes(cip_code, box_label)',
        );
      } catch (e) {
        // Index might already exist, ignore
      }
      dao = db.restockDao;
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'recordScan converts unique violations into duplicate outcome',
      () async {
        final cip = Cip13.validated('3400934056781');

        // Seed medicaments table for recordScan to find cis_code
        await db.customInsert(
          'INSERT INTO medicaments (code_cip, cis_code, presentation_label, commercialisation_statut, taux_remboursement, prix_public) VALUES (?, ?, ?, ?, ?, ?)',
          variables: [
            Variable.withString(cip.toString()),
            Variable.withString('CIS_TEST'),
            Variable.withString(''),
            Variable.withString('Commercialisée'),
            Variable.withString(''),
            Variable.withReal(0),
          ],
          updates: {db.medicaments},
        );

        final first = await dao.recordScan(
          cip: cip,
          serial: 'SERIAL-123',
          batchNumber: 'LOT-1',
        );
        expect(first, ScanOutcome.added);

        final second = await dao.recordScan(
          cip: cip,
          serial: 'SERIAL-123',
          batchNumber: 'LOT-1',
        );
        expect(second, ScanOutcome.duplicate);

        final rows = await db.select(db.scannedBoxes).get();
        expect(rows, hasLength(1));
        expect(rows.single.boxLabel, contains('SERIAL-123'));
      },
    );
  });
}
