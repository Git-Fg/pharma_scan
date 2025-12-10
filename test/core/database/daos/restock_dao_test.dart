import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/tables/scanned_boxes.drift.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';

void main() {
  group('RestockDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
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
      expect(rows.first.quantity, 1);

      await dao.addToRestock(cip);
      rows = await db.select(db.restockItems).get();
      expect(rows, hasLength(1));
      expect(rows.first.quantity, 2);
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
      expect(rows.single.quantity, 0);
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
      )..where((tbl) => tbl.cip.equals(cip.toString()))).getSingle();
      expect(row.isChecked, isFalse);

      await dao.toggleCheck(cip);
      row = await (db.select(
        db.restockItems,
      )..where((tbl) => tbl.cip.equals(cip.toString()))).getSingle();
      expect(row.isChecked, isTrue);
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
      expect(rows.first.cip, cip2.toString());
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
      expect(scannedRows.first.serialNumber, 'SER-A');

      final restockRows = await db.select(db.restockItems).get();
      expect(restockRows, hasLength(1));
      expect(restockRows.first.quantity, 1);

      final second = await dao.addUniqueBox(
        cip: cip,
        serial: 'SER-A',
        batchNumber: 'LOT-1',
      );
      expect(second, ScanOutcome.duplicate);

      final restockAfterDup = await db.select(db.restockItems).get();
      expect(restockAfterDup.single.quantity, 1);
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
      expect(restockRows.single.quantity, 1);

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
      expect(rows.single.quantity, 7);
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
      expect(rows.single.quantity, 0);
    });

    test('watchRestockItems maps form from summary', () async {
      final dao = db.restockDao;
      final cip = Cip13.validated('3400934056781');

      await db
          .into(db.specialites)
          .insert(
            SpecialitesCompanion.insert(
              cisCode: 'CIS_X',
              nomSpecialite: 'X',
              procedureType: 'proc',
              statutAdministratif: const Value('actif'),
              formePharmaceutique: const Value('Comprimé'),
              voiesAdministration: const Value('orale'),
              etatCommercialisation: const Value('ok'),
              titulaireId: const Value(1),
              conditionsPrescription: const Value(''),
              dateAmm: const Value(null),
              atcCode: const Value(null),
              isSurveillance: const Value(false),
            ),
          );
      await db
          .into(db.medicaments)
          .insert(
            MedicamentsCompanion.insert(
              codeCip: cip.toString(),
              cisCode: 'CIS_X',
              presentationLabel: const Value(''),
              commercialisationStatut: const Value(''),
              tauxRemboursement: const Value(null),
              prixPublic: const Value(null),
              agrementCollectivites: const Value(null),
            ),
          );
      await db
          .into(db.medicamentSummary)
          .insert(
            MedicamentSummaryCompanion.insert(
              cisCode: 'CIS_X',
              nomCanonique: 'Label',
              isPrinceps: true,
              groupId: const Value('G'),
              memberType: const Value(0),
              principesActifsCommuns: const [],
              princepsDeReference: 'Princeps',
              formePharmaceutique: const Value('Comprimé'),
              voiesAdministration: const Value('Orale'),
              princepsBrandName: 'Brand',
              procedureType: const Value('proc'),
              titulaireId: const Value(1),
              conditionsPrescription: const Value(null),
              dateAmm: const Value(null),
              isSurveillance: const Value(false),
              isDental: const Value(false),
              isList1: const Value(false),
              isList2: const Value(false),
              isNarcotic: const Value(false),
              isException: const Value(false),
              isRestricted: const Value(false),
              isOtc: const Value(true),
            ),
          );
      await dao.addToRestock(cip);

      final items = await dao.watchRestockItems().first;
      expect(items.single.form, 'Comprimé');
    });

    test('watchRestockItems falls back to specialites form', () async {
      final dao = db.restockDao;
      final cip = Cip13.validated('3400934056782');

      await db
          .into(db.specialites)
          .insert(
            SpecialitesCompanion.insert(
              cisCode: 'CIS_Y',
              nomSpecialite: 'Y',
              procedureType: 'proc',
              statutAdministratif: const Value('actif'),
              formePharmaceutique: const Value('Sirop'),
              voiesAdministration: const Value('orale'),
              etatCommercialisation: const Value('ok'),
              titulaireId: const Value(1),
              conditionsPrescription: const Value(''),
              dateAmm: const Value(null),
              atcCode: const Value(null),
              isSurveillance: const Value(false),
            ),
          );
      await db
          .into(db.medicaments)
          .insert(
            MedicamentsCompanion.insert(
              codeCip: cip.toString(),
              cisCode: 'CIS_Y',
              presentationLabel: const Value(''),
              commercialisationStatut: const Value(''),
              tauxRemboursement: const Value(null),
              prixPublic: const Value(null),
              agrementCollectivites: const Value(null),
            ),
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

      await (db.update(
        db.scannedBoxes,
      )..where((t) => t.cip.equals(cip1.toString()))).write(
        ScannedBoxesCompanion(
          scannedAt: Value(DateTime.utc(2024)),
        ),
      );
      await (db.update(
        db.scannedBoxes,
      )..where((t) => t.cip.equals(cip2.toString()))).write(
        ScannedBoxesCompanion(
          scannedAt: Value(DateTime.utc(2025)),
        ),
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
