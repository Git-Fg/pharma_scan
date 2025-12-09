import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/tables/restock_items.dart';
import 'package:pharma_scan/core/database/tables/scanned_boxes.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/history/domain/entities/scan_history_entry.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';
import 'package:sqlite3/sqlite3.dart';

part 'restock_dao.g.dart';

enum ScanOutcome { added, duplicate }

@DriftAccessor(
  tables: [
    Medicaments,
    MedicamentSummary,
    RestockItems,
    ScannedBoxes,
    Specialites,
  ],
)
class RestockDao extends DatabaseAccessor<AppDatabase> with _$RestockDaoMixin {
  RestockDao(super.attachedDatabase);

  Future<void> addToRestock(Cip13 cip) async {
    final cipString = cip.toString();

    final existing = await (select(
      restockItems,
    )..where((tbl) => tbl.cip.equals(cipString))).getSingleOrNull();

    final now = DateTime.now();

    if (existing == null) {
      await into(restockItems).insert(
        RestockItemsCompanion.insert(
          cip: cipString,
          quantity: const Value(1),
          isChecked: const Value(false),
          addedAt: Value(now),
        ),
      );
    } else {
      await (update(
        restockItems,
      )..where((tbl) => tbl.cip.equals(cipString))).write(
        RestockItemsCompanion(
          quantity: Value(existing.quantity + 1),
          addedAt: Value(now),
        ),
      );
    }
  }

  Future<void> updateQuantity(
    Cip13 cip,
    int delta, {
    bool allowZero = false,
  }) async {
    final cipString = cip.toString();

    await attachedDatabase.transaction(() async {
      final existing = await (select(
        restockItems,
      )..where((tbl) => tbl.cip.equals(cipString))).getSingleOrNull();

      if (existing == null) {
        return;
      }

      final newQuantity = existing.quantity + delta;
      final shouldDelete = allowZero ? newQuantity < 0 : newQuantity <= 0;
      if (shouldDelete) {
        await (delete(
          restockItems,
        )..where((tbl) => tbl.cip.equals(cipString))).go();
        await (delete(
          scannedBoxes,
        )..where((tbl) => tbl.cip.equals(cipString))).go();
      } else {
        await (update(
          restockItems,
        )..where((tbl) => tbl.cip.equals(cipString))).write(
          RestockItemsCompanion(
            quantity: Value(newQuantity),
            addedAt: Value(DateTime.now()),
          ),
        );
      }
    });
  }

  Future<void> deleteRestockItemFully(Cip13 cip) async {
    final cipString = cip.toString();

    await attachedDatabase.transaction(() async {
      await (delete(
        restockItems,
      )..where((tbl) => tbl.cip.equals(cipString))).go();

      await (delete(
        scannedBoxes,
      )..where((tbl) => tbl.cip.equals(cipString))).go();
    });
  }

  Future<void> toggleCheck(Cip13 cip) async {
    final cipString = cip.toString();

    final existing = await (select(
      restockItems,
    )..where((tbl) => tbl.cip.equals(cipString))).getSingleOrNull();

    if (existing == null) {
      return;
    }

    await (update(
      restockItems,
    )..where((tbl) => tbl.cip.equals(cipString))).write(
      RestockItemsCompanion(
        isChecked: Value(!existing.isChecked),
      ),
    );
  }

  Future<void> clearChecked() async {
    await (delete(
      restockItems,
    )..where((tbl) => tbl.isChecked.equals(true))).go();
  }

  Future<void> clearAll() async {
    await delete(restockItems).go();
    await delete(scannedBoxes).go();
  }

  Future<bool> isDuplicate({
    required String cip,
    required String serial,
  }) async {
    final rows =
        await (select(scannedBoxes)..where(
              (t) => t.cip.equals(cip) & t.serialNumber.equals(serial),
            ))
            .get();
    return rows.isNotEmpty;
  }

  Future<void> forceUpdateQuantity({
    required String cip,
    required int newQuantity,
  }) async {
    if (newQuantity < 0) {
      await deleteRestockItemFully(Cip13.validated(cip));
      return;
    }
    await into(restockItems).insertOnConflictUpdate(
      RestockItemsCompanion(
        cip: Value(cip),
        quantity: Value(newQuantity),
        addedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<int?> getRestockQuantity(String cip) async {
    final row = await (select(
      restockItems,
    )..where((tbl) => tbl.cip.equals(cip))).getSingleOrNull();
    return row?.quantity;
  }

  Future<ScanOutcome> recordScan({
    required Cip13 cip,
    String? serial,
    String? batchNumber,
    DateTime? expiryDate,
  }) async {
    try {
      await into(scannedBoxes).insert(
        ScannedBoxesCompanion.insert(
          cip: cip.toString(),
          serialNumber: Value(serial),
          batchNumber: Value(batchNumber),
          expiryDate: Value(expiryDate),
        ),
      );
      return ScanOutcome.added;
    } on SqliteException catch (e) {
      if (e.resultCode == 19 || e.extendedResultCode == 2067) {
        return ScanOutcome.duplicate;
      }
      rethrow;
    }
  }

  Stream<List<RestockItemEntity>> watchRestockItems() {
    final baseQuery = select(restockItems).join(
      [
        leftOuterJoin(
          medicaments,
          medicaments.codeCip.equalsExp(restockItems.cip),
        ),
        leftOuterJoin(
          medicamentSummary,
          medicamentSummary.cisCode.equalsExp(medicaments.cisCode),
        ),
        leftOuterJoin(
          specialites,
          specialites.cisCode.equalsExp(medicaments.cisCode),
        ),
      ],
    );

    return baseQuery.watch().map(
      (rows) {
        return rows.map((row) {
          final restockRow = row.readTable(restockItems);
          final summaryRow = row.readTableOrNull(medicamentSummary);
          final specialiteRow = row.readTableOrNull(specialites);

          final cip = Cip13.validated(restockRow.cip);

          final label = summaryRow?.nomCanonique ?? Strings.unknown;
          final princepsLabel = summaryRow?.princepsDeReference;
          final isPrinceps = summaryRow?.isPrinceps ?? false;
          final form =
              summaryRow?.formePharmaceutique ??
              specialiteRow?.formePharmaceutique;

          return RestockItemEntity(
            cip: cip,
            label: label,
            princepsLabel: princepsLabel,
            quantity: restockRow.quantity,
            isChecked: restockRow.isChecked,
            isPrinceps: isPrinceps,
            form: form,
          );
        }).toList();
      },
    );
  }

  Future<ScanOutcome> addUniqueBox({
    required Cip13 cip,
    String? serial,
    String? batchNumber,
    DateTime? expiryDate,
  }) async {
    final cipString = cip.toString();

    if (serial == null || serial.isEmpty) {
      await addToRestock(cip);
      return ScanOutcome.added;
    }

    try {
      await attachedDatabase.transaction(() async {
        await into(scannedBoxes).insert(
          ScannedBoxesCompanion.insert(
            cip: cipString,
            serialNumber: Value(serial),
            batchNumber: Value(batchNumber),
            expiryDate: Value(expiryDate),
          ),
        );
        await addToRestock(cip);
      });
      return ScanOutcome.added;
    } on SqliteException catch (e) {
      // 19 = constraint violation; 2067 = unique constraint failed
      if (e.resultCode == 19 || e.extendedResultCode == 2067) {
        return ScanOutcome.duplicate;
      }
      rethrow;
    }
  }

  Stream<List<ScanHistoryEntry>> watchScanHistory(int limit) {
    final safeLimit = limit < 1 ? 1 : (limit > 500 ? 500 : limit);
    return attachedDatabase
        .getScanHistory(safeLimit)
        .watch()
        .map((rows) => rows.map(ScanHistoryEntry.fromData).toList());
  }

  Future<void> clearHistory() async {
    await delete(scannedBoxes).go();
  }

  Stream<List<({Cip13 cip, int quantity})>> watchScannedBoxTotals() {
    const query =
        'SELECT cip, COUNT(*) AS quantity FROM scanned_boxes GROUP BY cip';
    return customSelect(
      query,
      readsFrom: {scannedBoxes},
    ).watch().map((rows) {
      return rows.map((row) {
        final cip = Cip13.validated(row.read<String>('cip'));
        final quantity = row.read<int>('quantity');
        return (cip: cip, quantity: quantity);
      }).toList();
    });
  }
}
