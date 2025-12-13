import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'preferences_service.g.dart';

/// Valid keys for SharedPreferences to prevent typo errors.
class PrefKeys {
  static const themeMode = 'theme_mode';
  static const updateFrequency = 'update_frequency';
  static const hapticEnabled = 'haptic_feedback_enabled';
  static const preferredSorting = 'preferred_sorting';
  static const scanHistoryLimit = 'scan_history_limit';
  static const bdpmVersion = 'bdpm_version';
  static const lastSyncEpoch = 'last_sync_epoch';
  static const sourceHashes = 'source_hashes';
  static const sourceDates = 'source_dates';
}

/// A synchronous wrapper around SharedPreferences.
/// This needs to be initialized before the app starts.
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  // --- Getters (Synchronous) ---
  String? getString(String key) => _prefs.getString(key);
  bool? getBool(String key) => _prefs.getBool(key);
  int? getInt(String key) => _prefs.getInt(key);

  // --- Setters (Async) ---
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
  Future<void> setBool(String key, {required bool value}) => _prefs.setBool(key, value);
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);
  Future<void> remove(String key) => _prefs.remove(key);

  // --- Source Hashes (JSON-encoded Map<String, String>) ---
  Map<String, String> getSourceHashes() {
    final raw = getString(PrefKeys.sourceHashes);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      );
    } on FormatException {
      return {};
    }
  }

  Future<void> setSourceHashes(Map<String, String> hashes) async {
    await setString(PrefKeys.sourceHashes, jsonEncode(hashes));
  }

  // --- Source Dates (JSON-encoded Map<String, String> with ISO8601 dates) ---
  Map<String, DateTime> getSourceDates() {
    final raw = getString(PrefKeys.sourceDates);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, DateTime>{};
      for (final entry in decoded.entries) {
        final parsed = DateTime.tryParse(entry.value?.toString() ?? '');
        if (parsed != null) {
          result[entry.key] = parsed;
        }
      }
      return result;
    } on FormatException {
      return {};
    }
  }

  Future<void> setSourceDates(Map<String, DateTime> dates) async {
    final encoded = dates.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    );
    await setString(PrefKeys.sourceDates, jsonEncode(encoded));
  }

  // --- Last Sync Time ---
  DateTime? getLastSyncTime() {
    final epoch = getInt(PrefKeys.lastSyncEpoch);
    if (epoch == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(epoch);
  }

  Future<void> setLastSyncTime(int epochMillis) async {
    await setInt(PrefKeys.lastSyncEpoch, epochMillis);
  }

  // --- Clear Sync Metadata ---
  Future<void> clearSourceMetadata() async {
    await remove(PrefKeys.sourceHashes);
    await remove(PrefKeys.sourceDates);
  }

  Future<void> resetSyncMetadata() async {
    await remove(PrefKeys.bdpmVersion);
    await remove(PrefKeys.lastSyncEpoch);
  }

  // --- Database Version Tag ---
  String? getDbVersionTag() => getString(PrefKeys.bdpmVersion);

  Future<void> setDbVersionTag(String? version) async {
    if (version == null) {
      await remove(PrefKeys.bdpmVersion);
    } else {
      await setString(PrefKeys.bdpmVersion, version);
    }
  }

  // --- BDPM Version (alias for backward compatibility) ---
  String? getBdpmVersion() => getString(PrefKeys.bdpmVersion);

  Future<void> setBdpmVersion(String? version) => setDbVersionTag(version);

  /// Clears all preferences (useful for testing and reset)
  Future<void> clear() => _prefs.clear();
}

/// Provider that will be overridden in main.dart with initialized instance.
@Riverpod(keepAlive: true)
PreferencesService preferencesService(Ref ref) {
  throw UnimplementedError(
    'preferencesServiceProvider must be overridden with an initialized '
    'PreferencesService instance in main.dart ProviderScope.overrides',
  );
}
