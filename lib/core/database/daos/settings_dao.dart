import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/daos/settings_dao.drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/models/app_setting.dart';

/// DAO pour gérer les paramètres de l'application.
///
/// Utilise la structure key-value du schéma SQL distant :
/// - key: TEXT PRIMARY KEY
/// - value: BLOB NOT NULL (sérialisé en JSON)
///
/// La table app_settings est définie dans le schéma SQL et accessible via customSelect/customUpdate.
@DriftAccessor()
class SettingsDao extends DatabaseAccessor<AppDatabase> with $SettingsDaoMixin {
  SettingsDao(super.attachedDatabase);

  /// Récupère une valeur depuis app_settings
  Future<T?> _getValue<T>(String key, T Function(dynamic) decoder) async {
    final rows = await customSelect(
      'SELECT value FROM app_settings WHERE key = ?',
      variables: [Variable<String>(key)],
      readsFrom: {},
    ).get();
    if (rows.isEmpty) return null;
    try {
      final blob = rows.first.read<Uint8List>('value');
      final json = jsonDecode(utf8.decode(blob));
      return decoder(json);
    } catch (_) {
      return null;
    }
  }

  /// Sauvegarde une valeur dans app_settings
  Future<void> _setValue(String key, dynamic value) async {
    final encoded = utf8.encode(jsonEncode(value));
    await customUpdate(
      'INSERT INTO app_settings (key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      variables: [
        Variable<String>(key),
        Variable<Uint8List>(Uint8List.fromList(encoded)),
      ],
      updates: {},
    );
  }

  /// Récupère toutes les settings sous forme de map
  Future<Map<String, dynamic>> _getAllSettings() async {
    final rows = await customSelect(
      'SELECT key, value FROM app_settings',
      readsFrom: {},
    ).get();
    final result = <String, dynamic>{};
    for (final row in rows) {
      try {
        final key = row.read<String>('key');
        final blob = row.read<Uint8List>('value');
        result[key] = jsonDecode(utf8.decode(blob));
      } catch (_) {
        // Ignore les valeurs invalides
      }
    }
    return result;
  }

  /// Récupère les settings avec une structure compatible avec l'ancienne API
  Future<AppSetting> getSettings() async {
    final settings = await _getAllSettings();
    return AppSetting(
      themeMode: settings['theme_mode'] as String? ?? 'system',
      updateFrequency: settings['update_frequency'] as String? ?? 'daily',
      bdpmVersion: settings['bdpm_version'] as String?,
      lastSyncEpoch: settings['last_sync_epoch'] as int?,
      sourceHashes: settings['source_hashes'] as String? ?? '{}',
      sourceDates: settings['source_dates'] as String? ?? '{}',
      hapticFeedbackEnabled:
          settings['haptic_feedback_enabled'] as bool? ?? true,
      preferredSorting: settings['preferred_sorting'] as String? ?? 'princeps',
      scanHistoryLimit: settings['scan_history_limit'] as int? ?? 100,
    );
  }

  /// Stream des settings
  Stream<AppSetting> watchSettings() async* {
    yield* customSelect(
      'SELECT key, value FROM app_settings',
      readsFrom: {},
    ).watch().asyncMap((_) => getSettings());
  }

  Future<String?> getBdpmVersion() async {
    return _getValue<String>('bdpm_version', (v) => v.toString());
  }

  Future<void> updateBdpmVersion(String? version) async {
    if (version == null) {
      await customUpdate(
        'DELETE FROM app_settings WHERE key = ?',
        variables: [const Variable<String>('bdpm_version')],
        updates: {},
      );
    } else {
      await _setValue('bdpm_version', version);
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    final epoch = await _getValue<int>('last_sync_epoch', (v) => v as int);
    if (epoch == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(epoch);
  }

  Future<void> updatePreferredSorting(String mode) async {
    await _setValue('preferred_sorting', mode);
  }

  Future<void> updateTheme(String mode) async {
    await _setValue('theme_mode', mode);
  }

  Future<void> updateSyncFrequency(String frequency) async {
    await _setValue('update_frequency', frequency);
  }

  Future<void> updateSyncTimestamp(int epochMillis) async {
    await _setValue('last_sync_epoch', epochMillis);
  }

  Future<Map<String, String>> getSourceHashes() async {
    final hashes = await _getValue<Map<String, dynamic>>(
      'source_hashes',
      (v) => v as Map<String, dynamic>,
    );
    if (hashes == null) return {};
    return hashes.map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }

  Future<void> saveSourceHashes(Map<String, String> hashes) async {
    await _setValue('source_hashes', hashes);
  }

  Future<Map<String, DateTime>> getSourceDates() async {
    final dates = await _getValue<Map<String, dynamic>>(
      'source_dates',
      (v) => v as Map<String, dynamic>,
    );
    if (dates == null) return {};
    final result = <String, DateTime>{};
    for (final entry in dates.entries) {
      final parsed = DateTime.tryParse(entry.value?.toString() ?? '');
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
    await _setValue('source_dates', encoded);
  }

  Future<void> updateSourceHashes(Map<String, String> hashes) async {
    await saveSourceHashes(hashes);
  }

  Future<void> clearSourceMetadata() async {
    await customUpdate(
      'DELETE FROM app_settings WHERE key IN (?, ?)',
      variables: [
        const Variable<String>('source_hashes'),
        const Variable<String>('source_dates'),
      ],
      updates: {},
    );
    await _setValue('source_hashes', <String, String>{});
    await _setValue('source_dates', <String, String>{});
  }

  /// Récupère la version de la DB pré-générée (stockée dans sourceHashes)
  Future<String?> getDbVersionTag() async {
    final hashes = await getSourceHashes();
    return hashes['db_version_tag'];
  }

  /// Sauvegarde la version de la DB pré-générée (dans sourceHashes)
  Future<void> setDbVersionTag(String? version) async {
    final hashes = await getSourceHashes();
    if (version != null) {
      hashes['db_version_tag'] = version;
    } else {
      hashes.remove('db_version_tag');
    }
    await saveSourceHashes(hashes);
  }

  Future<void> updateHapticFeedback({required bool enabled}) async {
    await _setValue('haptic_feedback_enabled', enabled);
  }

  Future<void> resetSettingsMetadata() async {
    await customUpdate(
      'DELETE FROM app_settings WHERE key IN (?, ?)',
      variables: [
        const Variable<String>('bdpm_version'),
        const Variable<String>('last_sync_epoch'),
      ],
      updates: {},
    );
  }
}
