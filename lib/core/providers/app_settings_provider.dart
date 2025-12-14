import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/providers.dart';
import '../database/daos/app_settings_dao.dart';

part 'app_settings_provider.g.dart';

/// Provider for accessing the AppSettingsDao
@Riverpod(keepAlive: true)
AppSettingsDao appSettingsDao(Ref ref) {
  return ref.read(databaseProvider()).appSettingsDao;
}

// --- Theme settings providers ---

@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  String? build() => ref.read(appSettingsDao).themeMode;

  Future<void> update(String mode) async {
    await ref.read(appSettingsDao).setThemeMode(mode);
    state = mode;
  }
}

@riverpod
class HapticEnabledNotifier extends _$HapticEnabledNotifier {
  @override
  bool? build() => ref.read(appSettingsDao).hapticEnabled;

  Future<void> update(bool enabled) async {
    await ref.read(appSettingsDao).setHapticEnabled(enabled);
    state = enabled;
  }
}

// --- User preferences providers ---

@riverpod
class UpdateFrequencyNotifier extends _$UpdateFrequencyNotifier {
  @override
  String? build() => ref.read(appSettingsDao).updateFrequency;

  Future<void> update(String frequency) async {
    await ref.read(appSettingsDao).setUpdateFrequency(frequency);
    state = frequency;
  }
}

@riverpod
class PreferredSortingNotifier extends _$PreferredSortingNotifier {
  @override
  String? build() => ref.read(appSettingsDao).preferredSorting;

  Future<void> update(String sorting) async {
    await ref.read(appSettingsDao).setPreferredSorting(sorting);
    state = sorting;
  }
}

@riverpod
class ScanHistoryLimitNotifier extends _$ScanHistoryLimitNotifier {
  @override
  int? build() => ref.read(appSettingsDao).scanHistoryLimit;

  Future<void> update(int limit) async {
    await ref.read(appSettingsDao).setScanHistoryLimit(limit);
    state = limit;
  }
}

// --- Sync metadata providers ---

@riverpod
class LastSyncEpochNotifier extends _$LastSyncEpochNotifier {
  @override
  int? build() => ref.read(appSettingsDao).lastSyncEpoch;

  Future<void> update(int epoch) async {
    await ref.read(appSettingsDao).setLastSyncEpoch(epoch);
    state = epoch;
  }

  Future<void> updateFromDateTime(DateTime time) async {
    final epoch = time.millisecondsSinceEpoch;
    await update(epoch);
  }
}

@riverpod
class BdpmVersionNotifier extends _$BdpmVersionNotifier {
  @override
  String? build() => ref.read(appSettingsDao).bdpmVersion;

  Future<void> update(String version) async {
    await ref.read(appSettingsDao).setBdpmVersion(version);
    state = version;
  }
}

@riverpod
class SourceHashesNotifier extends _$SourceHashesNotifier {
  @override
  Map<String, String> build() {
    // Using async build since we need to fetch from database
    throw UnimplementedError('Use sourceHashesFutureProvider instead');
  }
}

@riverpod
Future<Map<String, String>> sourceHashesFuture(Ref ref) async {
  return ref.read(appSettingsDao).sourceHashes;
}

@riverpod
class SourceDatesNotifier extends _$SourceDatesNotifier {
  @override
  Map<String, DateTime> build() {
    // Using async build since we need to fetch from database
    throw UnimplementedError('Use sourceDatesFutureProvider instead');
  }
}

@riverpod
Future<Map<String, DateTime>> sourceDatesFuture(Ref ref) async {
  return ref.read(appSettingsDao).sourceDates;
}