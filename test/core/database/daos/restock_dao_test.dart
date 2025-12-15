import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase database;
  late RestockDao dao;

  // Real CIPs existing in reference.db (Doliprane 1000mg & Aspirine 500mg)
  const cipDoliprane = '3400934168322';
  const cipAspirine = '3400930015678';

  setUp(() async {
    // Use the REAL reference database from assets/test/reference.db
    database = createTestDatabase(useRealReferenceDatabase: true);
    dao = database.restockDao;

    // No need to manually create tables or insert mock data!
    // The reference_db is attached and contains real data.
    // We only need to ensure scanned_boxes index exists as it's a user table (handled by migration or manually here if needed for specific tests)
    // Actually, AppDatabase.forTesting uses NativeDatabase.memory which runs migration?
    // NativeDatabase.memory documentation says it runs migration by default if we don't override it?
    // constructeur AppDatabase: super(_openConnection()) -> NativeDatabase
    // AppDatabase.forTesting passes `executor`.
    // Drift automatically runs migration on opening.
    // However, `restockItems` and `scannedBoxes` are in `user_schema.drift` which IS included in AppDatabase.
    // So they should be created automatically.
  });

  tearDown(() => database.close());

  test('addToRestock should increment quantity if item exists', () async {
    final cip = Cip13.validated(cipDoliprane);

    // 1. Premier ajout
    await dao.addToRestock(cip);

    // 2. Deuxième ajout (doublon métier)
    await dao.addToRestock(cip);

    final item = await dao.getRestockQuantity(cip);
    expect(item, 2); // Vérifie la logique "UPSERT"
  });

  test('updateQuantity should modify stock count correctly', () async {
    final cip = Cip13.validated(cipDoliprane);

    // Ajouter un item avec quantité initiale de 1
    await dao.addToRestock(cip);

    // Incrémenter de 3
    await dao.updateQuantity(cip, 3);

    final item = await dao.getRestockQuantity(cip);
    expect(item, 4); // 1 initial + 3 incrément = 4
  });

  test('deleteRestockItemFully should remove item completely', () async {
    final cip = Cip13.validated(cipDoliprane);

    // Ajouter un item
    await dao.addToRestock(cip);

    // Vérifier qu'il existe
    expect(await dao.getRestockQuantity(cip), 1);

    // Supprimer l'item
    await dao.deleteRestockItemFully(cip);

    // Vérifier qu'il n'existe plus
    expect(await dao.getRestockQuantity(cip), null);
  });

  test('clearAll should remove all items', () async {
    final cip1 = Cip13.validated(cipDoliprane);
    final cip2 = Cip13.validated(cipAspirine);

    // Ajouter deux items
    await dao.addToRestock(cip1);
    await dao.addToRestock(cip2);

    // Vérifier qu'ils existent
    expect(await dao.getRestockQuantity(cip1), 1);
    expect(await dao.getRestockQuantity(cip2), 1);

    // Effacer tous les items
    await dao.clearAll();

    // Vérifier qu'ils n'existent plus
    expect(await dao.getRestockQuantity(cip1), null);
    expect(await dao.getRestockQuantity(cip2), null);
  });

  test('toggleCheck should update checked state', () async {
    final cip = Cip13.validated(cipDoliprane);

    // Ajouter un item
    await dao.addToRestock(cip);

    // Basculer l'état (devrait être cochée)
    await dao.toggleCheck(cip);

    // Récupérer l'item pour vérifier l'état
    final item = await (database.select(database.restockItems)
          ..where((tbl) => tbl.cipCode.equals(cip.toString())))
        .getSingleOrNull();
    // Notes is a JSON string
    expect(item?.notes, contains('"checked":true'));

    // Basculer à nouveau (devrait être décochée)
    await dao.toggleCheck(cip);

    // Récupérer à nouveau
    final item2 = await (database.select(database.restockItems)
          ..where((tbl) => tbl.cipCode.equals(cip.toString())))
        .getSingleOrNull();
    expect(item2?.notes, contains('"checked":false'));
  });

  test('recordScan should detect duplicate scans', () async {
    final cip = Cip13.validated(cipDoliprane);

    // First insertion should be added
    final outcome1 = await dao.recordScan(cip: cip, serial: 'ABC123');
    expect(outcome1, ScanOutcome.added);

    // Second insertion with same serial should be detected as duplicate
    final outcome2 = await dao.recordScan(cip: cip, serial: 'ABC123');
    expect(outcome2, ScanOutcome.duplicate);
  });

  test('updateQuantity should allow zero when allowZero is true', () async {
    final cip = Cip13.validated(cipDoliprane);

    // Add item with initial quantity
    await dao.addToRestock(cip);
    expect(await dao.getRestockQuantity(cip), 1);

    // Decrement to zero with allowZero=true
    await dao.updateQuantity(cip, -1, allowZero: true);

    // Item should still exist with zero quantity
    expect(await dao.getRestockQuantity(cip), 0);
  });

  test('updateQuantity should delete item when reaching zero without allowZero',
      () async {
    final cip = Cip13.validated(cipDoliprane);

    // Add item with initial quantity
    await dao.addToRestock(cip);
    expect(await dao.getRestockQuantity(cip), 1);

    // Decrement to zero without allowZero (default behavior)
    await dao.updateQuantity(cip, -1);

    // Item should be deleted
    expect(await dao.getRestockQuantity(cip), null);
  });

  test('isDuplicate should correctly identify cip+serial combinations',
      () async {
    final cip1 = Cip13.validated(cipDoliprane);
    final cip2 = Cip13.validated(cipAspirine);

    // Add scans with different cip+serial combinations
    await dao.recordScan(cip: cip1, serial: 'SERIAL_A');
    await dao.recordScan(cip: cip1, serial: 'SERIAL_B');
    await dao.recordScan(cip: cip2, serial: 'SERIAL_A');

    // Verify each combination is uniquely identified
    expect(await dao.isDuplicate(cip: cip1, serial: 'SERIAL_A'), isTrue);
    expect(await dao.isDuplicate(cip: cip1, serial: 'SERIAL_B'), isTrue);
    expect(await dao.isDuplicate(cip: cip2, serial: 'SERIAL_A'), isTrue);

    // Different combinations should not be duplicates
    expect(await dao.isDuplicate(cip: cip1, serial: 'SERIAL_C'), isFalse);
    expect(await dao.isDuplicate(cip: cip2, serial: 'SERIAL_B'), isFalse);
  });

  test('addUniqueBox should handle serial-less scans correctly', () async {
    final cip = Cip13.validated(cipDoliprane);

    // Add box without serial
    final outcome = await dao.addUniqueBox(cip: cip);
    expect(outcome, ScanOutcome.added);

    // Verify item added to restock
    expect(await dao.getRestockQuantity(cip), 1);
  });
}
