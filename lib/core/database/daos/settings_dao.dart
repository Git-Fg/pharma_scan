import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/tables/settings.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.attachedDatabase);

  static const _settingsRowId = 1;

  Future<AppSetting> _getOrCreateSettingsRow() async {
    final existing = await (select(
      appSettings,
    )..where((tbl) => tbl.id.equals(_settingsRowId))).getSingleOrNull();
    if (existing != null) return existing;

    await into(appSettings).insertOnConflictUpdate(
      const AppSettingsCompanion(id: Value(_settingsRowId)),
    );

    return (select(
      appSettings,
    )..where((tbl) => tbl.id.equals(_settingsRowId))).getSingle();
  }

  Future<AppSetting> getSettings() async => _getOrCreateSettingsRow();

  Stream<AppSetting> watchSettings() async* {
    await _ensureSettingsRow();
    yield* (select(
      appSettings,
    )..where((tbl) => tbl.id.equals(_settingsRowId))).watchSingle();
  }

  Future<String?> getBdpmVersion() async {
    final settings = await getSettings();
    return settings.bdpmVersion;
  }

  Future<void> _ensureSettingsRow() async {
    await _getOrCreateSettingsRow();
  }

  Future<void> updateBdpmVersion(String? version) async {
    await _ensureSettingsRow();
    await (update(
      appSettings,
    )..where((tbl) => tbl.id.equals(_settingsRowId))).write(
      AppSettingsCompanion(bdpmVersion: Value(version)),
    );
  }

  Future<DateTime?> getLastSyncTime() async {
    final settings = await getSettings();
    final millis = settings.lastSyncEpoch;
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> updatePreferredSorting(String mode) async {
    await _ensureSettingsRow();
    await (update(
      appSettings,
    )..where((tbl) => tbl.id.equals(_settingsRowId))).write(
      AppSettingsCompanion(preferredSorting: Value(mode)),
    );
  }

  Future<void> updateTheme(String mode) async {
    await _ensureSettingsRow();
    await (update(
      appSettings,
    )..where((tbl) => tbl.id.equals(_settingsRowId))).write(
      AppSettingsCompanion(themeMode: Value(mode)),
    );
  }

  Future<void> updateSyncFrequency(String frequency) async {
    await _ensureSettingsRow();
    await (update(
      appSettings,
    )..where((tbl) => tbl.id.equals(_settingsRowId))).write(
      AppSettingsCompanion(updateFrequency: Value(frequency)),
    );
  }

  Future<void> updateSyncTimestamp(int epochMillis) async {
    await _ensureSettingsRow();
    await (update(
      appSettings,
    )..where((tbl) => tbl.id.equals(_settingsRowId))).write(
      AppSettingsCompanion(lastSyncEpoch: Value(epochMillis)),
    );
  }

  Future<Map<String, String>> getSourceHashes() async {
    final settings = await getSettings();
    return _decodeStringMap(settings.sourceHashes);
  }

  Future<void> saveSourceHashes(Map<String, String> hashes) async {
    await _ensureSettingsRow();
    await (update(
      appSettings,
    )..where((tbl) => tbl.id.equals(_settingsRowId))).write(
      AppSettingsCompanion(sourceHashes: Value(jsonEncode(hashes))),
    );
  }

  Future<Map<String, DateTime>> getSourceDates() async {
    final settings = await getSettings();
    final decoded = _decodeStringMap(settings.sourceDates);
    final result = <String, DateTime>{};
    for (final entry in decoded.entries) {
      final parsed = DateTime.tryParse(entry.value);
      if (parsed != null) {
        result[entry.key] = parsed;
      }
    }
    return result;
  }

  Future<void> saveSourceDates(Map<String, DateTime> dates) async {
    await _ensureSettingsRow();
    final encoded = dates.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    );
    await (update(
      appSettings,
    )..where((tbl) => tbl.id.equals(_settingsRowId))).write(
      AppSettingsCompanion(sourceDates: Value(jsonEncode(encoded))),
    );
  }

  Future<void> updateSourceHashes(Map<String, String> hashes) async {
    await _ensureSettingsRow();
    await (update(
      appSettings,
    )..where((tbl) => tbl.id.equals(_settingsRowId))).write(
      AppSettingsCompanion(sourceHashes: Value(jsonEncode(hashes))),
    );
  }

  Future<void> clearSourceMetadata() async {
    await _ensureSettingsRow();
    await (update(
      appSettings,
    )..where((tbl) => tbl.id.equals(_settingsRowId))).write(
      const AppSettingsCompanion(
        sourceHashes: Value('{}'),
        sourceDates: Value('{}'),
      ),
    );
  }

  Future<void> updateHapticFeedback({required bool enabled}) async {
    await _ensureSettingsRow();
    await (update(
      appSettings,
    )..where((tbl) => tbl.id.equals(_settingsRowId))).write(
      AppSettingsCompanion(
        hapticFeedbackEnabled: Value(enabled),
      ),
    );
  }

  Future<void> resetSettingsMetadata() async {
    await _ensureSettingsRow();
    await (update(
      appSettings,
    )..where((tbl) => tbl.id.equals(_settingsRowId))).write(
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
      if (decoded is Map<String, dynamic>) {
        return decoded.map(
          (key, value) => MapEntry(key, value?.toString() ?? ''),
        );
      }
    } on Exception {
      // ignore decode errors and return empty map
    }
    return {};
  }
}
