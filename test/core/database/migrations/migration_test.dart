import 'dart:io';

import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:pharma_scan/core/database/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:test/test.dart';

void main() {
  group('Database migration', () {
    late Directory tmpDir;
    late File dbFile;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('pharma_migration_test');
      dbFile = File(p.join(tmpDir.path, 'app.db'));
    });

    tearDown(() async {
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      await tmpDir.delete(recursive: true);
    });

    test(
      'upgrading from v7 preserves data and applies defaults',
      () async {
        final raw = sqlite.sqlite3.open(dbFile.path);
        configureAppSQLite(raw);

        raw
          ..execute('''
CREATE TABLE restock_items(
  cip TEXT PRIMARY KEY,
  quantity INTEGER NOT NULL DEFAULT 1,
  is_checked INTEGER NOT NULL DEFAULT 0,
  added_at INTEGER NOT NULL
);
''')
          ..execute('''
CREATE TABLE scanned_boxes(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  cip TEXT NOT NULL,
  serial_number TEXT,
  batch_number TEXT,
  expiry_date INTEGER,
  scanned_at INTEGER NOT NULL,
  UNIQUE(cip, serial_number)
);
''')
          ..execute('''
CREATE TABLE app_settings(
  id INTEGER PRIMARY KEY DEFAULT 1,
  theme_mode TEXT DEFAULT 'system',
  update_frequency TEXT DEFAULT 'daily',
  bdpm_version TEXT,
  last_sync_epoch INTEGER,
  source_hashes TEXT DEFAULT '{}',
  source_dates TEXT DEFAULT '{}',
  haptic_feedback_enabled INTEGER NOT NULL DEFAULT 1,
  preferred_sorting TEXT DEFAULT 'princeps'
);
''')
          ..execute(
            "INSERT INTO restock_items (cip, quantity, is_checked, added_at) VALUES (?, ?, ?, strftime('%s', 'now'))",
            ['3400934056781', 2, 1],
          )
          ..execute(
            "INSERT INTO scanned_boxes (cip, serial_number, batch_number, expiry_date, scanned_at) VALUES (?, ?, ?, ?, strftime('%s', 'now'))",
            ['3400934056781', 'SER123', 'LOT1', null],
          )
          ..execute(
            "INSERT INTO app_settings (id, theme_mode, update_frequency) VALUES (1, 'system', 'daily')",
          )
          ..execute('PRAGMA user_version = 7')
          ..dispose();

        final db = AppDatabase.forTesting(
          NativeDatabase(dbFile, setup: configureAppSQLite),
        );

        final restockRows = await db.select(db.restockItems).get();
        final scannedRows = await db.select(db.scannedBoxes).get();
        final settings = await db.select(db.appSettings).getSingle();
        final userVersionRow = await db
            .customSelect('PRAGMA user_version')
            .getSingle();

        expect(restockRows, hasLength(1));
        expect(restockRows.first.cip, '3400934056781');
        expect(restockRows.first.quantity, 2);
        expect(restockRows.first.isChecked, isTrue);

        expect(scannedRows, hasLength(1));
        expect(scannedRows.first.cip, '3400934056781');
        expect(scannedRows.first.serialNumber, 'SER123');

        expect(settings.scanHistoryLimit, 100);
        expect(userVersionRow.data.values.first, db.schemaVersion);

        await db.close();
      },
      skip: 'Schema reset to v1 with drift_flutter; legacy migrations removed.',
    );
  });
}
