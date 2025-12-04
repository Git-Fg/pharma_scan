import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
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
  });
}
