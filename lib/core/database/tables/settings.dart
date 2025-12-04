import 'package:drift/drift.dart';

class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  // Configuration
  TextColumn get themeMode => text().withDefault(
    const Constant('system'),
  )(); // 'system', 'light', 'dark'
  TextColumn get updateFrequency => text().withDefault(
    const Constant('daily'),
  )(); // 'daily', 'weekly', 'none'

  // Sync Metadata
  TextColumn get bdpmVersion => text().nullable()();
  IntColumn get lastSyncEpoch =>
      integer().nullable()(); // DateTime stored as milliseconds
  TextColumn get sourceHashes =>
      text().withDefault(const Constant('{}'))(); // JSON map of file hashes
  TextColumn get sourceDates => text().withDefault(
    const Constant('{}'),
  )(); // JSON map of last update ISO strings

  // Haptics
  BoolColumn get hapticFeedbackEnabled =>
      boolean().withDefault(const Constant(true))();

  // Global sorting preference for explorer & restock lists.
  // Values: 'princeps' (default), 'generic'.
  TextColumn get preferredSorting =>
      text().withDefault(const Constant('princeps'))();

  @override
  Set<Column> get primaryKey => {id};
}
