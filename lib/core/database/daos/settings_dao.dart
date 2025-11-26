// lib/core/database/daos/settings_dao.dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/tables/settings.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.db);

  Future<AppSetting> getSettings() async {
    final row = await (select(
      appSettings,
    )..where((tbl) => tbl.id.equals(1))).getSingleOrNull();
    if (row != null) return row;

    await into(appSettings).insert(
      const AppSettingsCompanion(id: Value(1)),
      mode: InsertMode.insertOrIgnore,
    );

    return (select(appSettings)..where((tbl) => tbl.id.equals(1))).getSingle();
  }

  Stream<AppSetting> watchSettings() {
    final selectSettings = (select(appSettings)
      ..where((tbl) => tbl.id.equals(1)));

    return selectSettings.watchSingleOrNull().asyncMap((row) async {
      if (row != null) return row;

      await into(appSettings).insert(
        const AppSettingsCompanion(id: Value(1)),
        mode: InsertMode.insertOrIgnore,
      );
      return (select(
        appSettings,
      )..where((tbl) => tbl.id.equals(1))).getSingle();
    });
  }

  Future<String?> getBdpmVersion() async {
    final settings = await getSettings();
    return settings.bdpmVersion;
  }

  Future<void> updateBdpmVersion(String? version) async {
    await (update(appSettings)..where((tbl) => tbl.id.equals(1))).write(
      AppSettingsCompanion(bdpmVersion: Value(version)),
    );
  }

  Future<DateTime?> getLastSyncTime() async {
    final settings = await getSettings();
    final millis = settings.lastSyncEpoch;
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> updateTheme(String mode) async {
    await (update(appSettings)..where((tbl) => tbl.id.equals(1))).write(
      AppSettingsCompanion(themeMode: Value(mode)),
    );
  }

  Future<void> updateSyncFrequency(String frequency) async {
    await (update(appSettings)..where((tbl) => tbl.id.equals(1))).write(
      AppSettingsCompanion(updateFrequency: Value(frequency)),
    );
  }

  Future<void> updateSyncTimestamp(int epochMillis) async {
    await (update(appSettings)..where((tbl) => tbl.id.equals(1))).write(
      AppSettingsCompanion(lastSyncEpoch: Value(epochMillis)),
    );
  }

  Future<Map<String, String>> getSourceHashes() async {
    final settings = await getSettings();
    return _decodeStringMap(settings.sourceHashes);
  }

  Future<void> saveSourceHashes(Map<String, String> hashes) async {
    await (update(appSettings)..where((tbl) => tbl.id.equals(1))).write(
      AppSettingsCompanion(sourceHashes: Value(jsonEncode(hashes))),
    );
  }

  Future<Map<String, DateTime>> getSourceDates() async {
    final settings = await getSettings();
    final raw = _decodeStringMap(settings.sourceDates);
    final result = <String, DateTime>{};
    for (final entry in raw.entries) {
      final parsed = DateTime.tryParse(entry.value);
      if (parsed != null) {
        result[entry.key] = parsed;
      }
    }
    return result;
  }

  Future<void> saveSourceDates(Map<String, DateTime> dates) async {
    final encoded = dates.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    );
    await (update(appSettings)..where((tbl) => tbl.id.equals(1))).write(
      AppSettingsCompanion(sourceDates: Value(jsonEncode(encoded))),
    );
  }

  Future<void> clearSourceMetadata() async {
    await (update(appSettings)..where((tbl) => tbl.id.equals(1))).write(
      const AppSettingsCompanion(
        sourceHashes: Value('{}'),
        sourceDates: Value('{}'),
      ),
    );
  }

  Future<void> resetSettingsMetadata() async {
    await (update(appSettings)..where((tbl) => tbl.id.equals(1))).write(
      const AppSettingsCompanion(
        bdpmVersion: Value(null),
        lastSyncEpoch: Value(null),
      ),
    );
  }

  Map<String, String> _decodeStringMap(String raw) {
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
      }
    } catch (_) {
      return {};
    }
    return {};
  }
}
