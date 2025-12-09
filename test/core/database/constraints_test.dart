import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';

void main() {
  group('Database constraints', () {
    late AppDatabase db;
    late RestockDao dao;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = db.restockDao;
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'recordScan converts unique violations into duplicate outcome',
      () async {
        final cip = Cip13.validated('3400934056781');

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
        expect(rows.single.serialNumber, 'SERIAL-123');
      },
    );
  });
}
