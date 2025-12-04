import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/tables/restock_items.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';

part 'restock_dao.g.dart';

@DriftAccessor(tables: [Medicaments, MedicamentSummary, RestockItems])
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

  Future<void> updateQuantity(Cip13 cip, int delta) async {
    final cipString = cip.toString();

    final existing = await (select(
      restockItems,
    )..where((tbl) => tbl.cip.equals(cipString))).getSingleOrNull();

    if (existing == null) {
      return;
    }

    final newQuantity = existing.quantity + delta;
    if (newQuantity <= 0) {
      await (delete(
        restockItems,
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
      ],
    );

    return baseQuery.watch().map(
      (rows) {
        return rows.map((row) {
          final restockRow = row.readTable(restockItems);
          final summaryRow = row.readTableOrNull(medicamentSummary);

          final cip = Cip13.validated(restockRow.cip);

          final label = summaryRow?.nomCanonique ?? Strings.unknown;
          final princepsLabel = summaryRow?.princepsDeReference;
          final isPrinceps = summaryRow?.isPrinceps ?? false;

          return RestockItemEntity(
            cip: cip,
            label: label,
            princepsLabel: princepsLabel,
            quantity: restockRow.quantity,
            isChecked: restockRow.isChecked,
            isPrinceps: isPrinceps,
          );
        }).toList();
      },
    );
  }
}
