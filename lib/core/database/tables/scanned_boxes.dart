import 'package:drift/drift.dart';

/// Per-box scan journal to enforce serial-number uniqueness.
@TableIndex(name: 'idx_unique_box', columns: {#cip, #serialNumber})
class ScannedBoxes extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Product code (AI 01 / CIP-13).
  TextColumn get cip => text()();

  /// Unique serial number (AI 21). Nullable for legacy stock without serials.
  TextColumn get serialNumber => text().nullable()();

  /// Batch / lot number (AI 10).
  TextColumn get batchNumber => text().nullable()();

  /// Expiration date (AI 17).
  DateTimeColumn get expiryDate => dateTime().nullable()();

  /// Scan timestamp.
  DateTimeColumn get scannedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {cip, serialNumber},
  ];
}
