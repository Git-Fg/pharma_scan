import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/daos/settings_dao.drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/tables/settings.dart';
import 'package:pharma_scan/core/database/tables/settings.drift.dart';

@DriftAccessor(tables: [AppSettings])
class SettingsDao extends DatabaseAccessor<AppDatabase> with $SettingsDaoMixin {
  SettingsDao(super.attachedDatabase);

  static const _settingsRowId = 1;

  Future<AppSetting> _getOrCreateSettingsRow() async {
    final settingsManager = attachedDatabase.managers.appSettings;

    final existing = await settingsManager
        .filter((tbl) => tbl.id.equals(_settingsRowId))
        .getSingleOrNull();
    if (existing != null) return existing;

    await settingsManager.create(
      (tbl) => tbl(id: const Value(_settingsRowId)),
      mode: InsertMode.insertOrReplace,
    );

    return settingsManager
        .filter((tbl) => tbl.id.equals(_settingsRowId))
        .getSingle();
  }

  Future<AppSetting> getSettings() async => _getOrCreateSettingsRow();

  Stream<AppSetting> watchSettings() async* {
    await _ensureSettingsRow();
    yield* attachedDatabase.managers.appSettings
        .filter((tbl) => tbl.id.equals(_settingsRowId))
        .watchSingle();
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
    await attachedDatabase.managers.appSettings
        .filter((tbl) => tbl.id.equals(_settingsRowId))
        .update((tbl) => tbl(bdpmVersion: Value(version)));
  }

  Future<DateTime?> getLastSyncTime() async {
    final settings = await getSettings();
    final millis = settings.lastSyncEpoch;
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> updatePreferredSorting(String mode) async {
    await _ensureSettingsRow();
    await attachedDatabase.managers.appSettings
        .filter((tbl) => tbl.id.equals(_settingsRowId))
        .update((tbl) => tbl(preferredSorting: Value(mode)));
  }

  Future<void> updateTheme(String mode) async {
    await _ensureSettingsRow();
    await attachedDatabase.managers.appSettings
        .filter((tbl) => tbl.id.equals(_settingsRowId))
        .update((tbl) => tbl(themeMode: Value(mode)));
  }

  Future<void> updateSyncFrequency(String frequency) async {
    await _ensureSettingsRow();
    await attachedDatabase.managers.appSettings
        .filter((tbl) => tbl.id.equals(_settingsRowId))
        .update((tbl) => tbl(updateFrequency: Value(frequency)));
  }

  Future<void> updateSyncTimestamp(int epochMillis) async {
    await _ensureSettingsRow();
    await attachedDatabase.managers.appSettings
        .filter((tbl) => tbl.id.equals(_settingsRowId))
        .update((tbl) => tbl(lastSyncEpoch: Value(epochMillis)));
  }

  Future<Map<String, String>> getSourceHashes() async {
    final settings = await getSettings();
    return _decodeStringMap(settings.sourceHashes);
  }

  Future<void> saveSourceHashes(Map<String, String> hashes) async {
    await _ensureSettingsRow();
    await attachedDatabase.managers.appSettings
        .filter((tbl) => tbl.id.equals(_settingsRowId))
        .update((tbl) => tbl(sourceHashes: Value(jsonEncode(hashes))));
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
    await attachedDatabase.managers.appSettings
        .filter((tbl) => tbl.id.equals(_settingsRowId))
        .update((tbl) => tbl(sourceDates: Value(jsonEncode(encoded))));
  }

  Future<void> updateSourceHashes(Map<String, String> hashes) async {
    await _ensureSettingsRow();
    await attachedDatabase.managers.appSettings
        .filter((tbl) => tbl.id.equals(_settingsRowId))
        .update((tbl) => tbl(sourceHashes: Value(jsonEncode(hashes))));
  }

  Future<void> clearSourceMetadata() async {
    await _ensureSettingsRow();
    await attachedDatabase.managers.appSettings
        .filter((tbl) => tbl.id.equals(_settingsRowId))
        .update(
          (tbl) => tbl(
            sourceHashes: const Value('{}'),
            sourceDates: const Value('{}'),
          ),
        );
  }

  /// Récupère la version de la DB pré-générée (stockée dans sourceHashes)
  Future<String?> getDbVersionTag() async {
    final hashes = await getSourceHashes();
    return hashes['db_version_tag'];
  }

  /// Sauvegarde la version de la DB pré-générée (dans sourceHashes)
  Future<void> setDbVersionTag(String? version) async {
    await _ensureSettingsRow();
    final hashes = await getSourceHashes();
    if (version != null) {
      hashes['db_version_tag'] = version;
    } else {
      hashes.remove('db_version_tag');
    }
    await saveSourceHashes(hashes);
  }

  Future<void> updateHapticFeedback({required bool enabled}) async {
    await _ensureSettingsRow();
    await attachedDatabase.managers.appSettings
        .filter((tbl) => tbl.id.equals(_settingsRowId))
        .update(
          (tbl) => tbl(
            hapticFeedbackEnabled: Value(enabled),
          ),
        );
  }

  Future<void> resetSettingsMetadata() async {
    await _ensureSettingsRow();
    await attachedDatabase.managers.appSettings
        .filter((tbl) => tbl.id.equals(_settingsRowId))
        .update(
          (tbl) => tbl(
            bdpmVersion: const Value(null),
            lastSyncEpoch: const Value(null),
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
