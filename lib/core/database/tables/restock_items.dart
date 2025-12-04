import 'package:drift/drift.dart';

/// Persistent restock list items.
///
/// Uses CIP-13 as the primary key so each product appears at most once.
@TableIndex(name: 'idx_restock_added', columns: {#addedAt})
class RestockItems extends Table {
  /// CIP-13 code for the medicament presentation.
  TextColumn get cip => text()();

  /// Quantity to restock, defaults to 1.
  IntColumn get quantity => integer().withDefault(const Constant(1))();

  /// Whether the item has been processed/checked.
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();

  /// Timestamp of the last addition/update to the restock list.
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {cip};
}
