import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/tables/app_settings_table.drift.dart';

/// App setting keys for type-safe access
class AppSettingKeys {
  AppSettingKeys._(); // Private constructor to prevent instantiation

  // Theme settings
  static const themeMode = 'theme_mode';
  static const hapticEnabled = 'haptic_feedback_enabled';

  // User preferences
  static const updateFrequency = 'update_frequency';
  static const preferredSorting = 'preferred_sorting';
  static const scanHistoryLimit = 'scan_history_limit';

  // Sync metadata
  static const bdpmVersion = 'bdpm_version';
  static const lastSyncEpoch = 'last_sync_epoch';
  static const sourceHashes = 'source_hashes';
  static const sourceDates = 'source_dates';
}

/// Extension methods for AppSetting to handle different data types
extension AppSettingExtension on AppSetting {
  T? getValue<T>() {
    final data = value;

    final str = utf8.decode(data);
    dynamic parsed;
    if (T == String) {
      parsed = str;
    } else if (T == int) {
      parsed = int.tryParse(str);
    } else if (T == bool) {
      parsed = str.toLowerCase() == 'true';
    } else if (T == double) {
      parsed = double.tryParse(str);
    } else if (T.toString().contains('Map')) {
      try {
        parsed = jsonDecode(str) as Map<String, dynamic>;
      } on FormatException {
        parsed = null;
      }
    } else {
      parsed = str;
    }
    return parsed as T?;
  }
}

/// DAO for managing app settings with type-safe accessors
@DriftAccessor()
class AppSettingsDao extends DatabaseAccessor<AppDatabase> {
  AppSettingsDao(super.db);

  $AppSettingsTable get _appSettings => attachedDatabase.appSettings;

  // --- Generic CRUD operations ---
  Future<T?> getSetting<T>(String key) async {
    final setting = await (attachedDatabase.select(_appSettings)
          ..where((tbl) => tbl.key.equals(key)))
        .getSingleOrNull();
    return setting?.getValue<T>();
  }

  Future<void> setSetting<T>(String key, T value) async {
    final encoded = _encodeValue(value);
    await attachedDatabase.into(_appSettings).insertOnConflictUpdate(
          AppSettingsCompanion(
            key: Value(key),
            value: Value(encoded),
          ),
        );
  }

  Future<void> removeSetting(String key) async {
    await (attachedDatabase.delete(_appSettings)
          ..where((tbl) => tbl.key.equals(key)))
        .go();
  }

  Future<bool> hasSetting(String key) async {
    final result = await (attachedDatabase.selectOnly(_appSettings)
          ..where(_appSettings.key.equals(key)))
        .get();
    return result.isNotEmpty;
  }

  // --- Theme settings ---
  Future<String?> get themeMode => getSetting<String>(AppSettingKeys.themeMode);
  Future<void> setThemeMode(String mode) =>
      setSetting(AppSettingKeys.themeMode, mode);

  Future<bool?> get hapticEnabled =>
      getSetting<bool>(AppSettingKeys.hapticEnabled);
  Future<void> setHapticEnabled(bool enabled) =>
      setSetting(AppSettingKeys.hapticEnabled, enabled);

  // --- User preferences ---
  Future<String?> get updateFrequency =>
      getSetting<String>(AppSettingKeys.updateFrequency);
  Future<void> setUpdateFrequency(String frequency) =>
      setSetting(AppSettingKeys.updateFrequency, frequency);

  Future<String?> get preferredSorting =>
      getSetting<String>(AppSettingKeys.preferredSorting);
  Future<void> setPreferredSorting(String sorting) =>
      setSetting(AppSettingKeys.preferredSorting, sorting);

  Future<int?> get scanHistoryLimit =>
      getSetting<int>(AppSettingKeys.scanHistoryLimit);
  Future<void> setScanHistoryLimit(int limit) =>
      setSetting(AppSettingKeys.scanHistoryLimit, limit);

  // --- Sync metadata ---
  Future<String?> get bdpmVersion =>
      getSetting<String>(AppSettingKeys.bdpmVersion);
  Future<void> setBdpmVersion(String version) =>
      setSetting(AppSettingKeys.bdpmVersion, version);

  Future<int?> get lastSyncEpoch =>
      getSetting<int>(AppSettingKeys.lastSyncEpoch);
  Future<void> setLastSyncEpoch(int epoch) =>
      setSetting(AppSettingKeys.lastSyncEpoch, epoch);

  Future<DateTime?> get lastSyncTime async {
    final epoch = await lastSyncEpoch;
    if (epoch == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(epoch);
  }

  Future<void> setLastSyncTime(DateTime time) async {
    await setLastSyncEpoch(time.millisecondsSinceEpoch);
  }

  // --- Source hashes (JSON-encoded Map<String, String>) ---
  Future<Map<String, String>> get sourceHashes async {
    final value =
        await getSetting<Map<String, dynamic>>(AppSettingKeys.sourceHashes);
    if (value == null) return {};
    return value.map((key, val) => MapEntry(key, val?.toString() ?? ''));
  }

  Future<void> setSourceHashes(Map<String, String> hashes) async {
    await setSetting(AppSettingKeys.sourceHashes, hashes);
  }

  // --- Source dates (JSON-encoded Map<String, DateTime>) ---
  Future<Map<String, DateTime>> get sourceDates async {
    final value =
        await getSetting<Map<String, dynamic>>(AppSettingKeys.sourceDates);
    if (value == null) return {};

    final result = <String, DateTime>{};
    for (final entry in value.entries) {
      final parsed = DateTime.tryParse(entry.value?.toString() ?? '');
      if (parsed != null) {
        result[entry.key] = parsed;
      }
    }
    return result;
  }

  Future<void> setSourceDates(Map<String, DateTime> dates) async {
    final encoded = dates.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    );
    await setSetting(AppSettingKeys.sourceDates, encoded);
  }

  // --- Utility methods ---
  Future<void> clearSourceMetadata() async {
    await removeSetting(AppSettingKeys.sourceHashes);
    await removeSetting(AppSettingKeys.sourceDates);
  }

  Future<void> resetSyncMetadata() async {
    await removeSetting(AppSettingKeys.bdpmVersion);
    await removeSetting(AppSettingKeys.lastSyncEpoch);
  }

  Future<void> clearAll() async {
    await attachedDatabase.delete(_appSettings).go();
  }

  // --- Private helper methods ---
  Uint8List _encodeValue(dynamic value) {
    if (value is String) {
      return Uint8List.fromList(utf8.encode(value));
    } else if (value is int || value is double || value is bool) {
      return Uint8List.fromList(utf8.encode(value.toString()));
    } else if (value is Map) {
      return Uint8List.fromList(utf8.encode(jsonEncode(value)));
    } else {
      return Uint8List.fromList(utf8.encode(value.toString()));
    }
  }
}
