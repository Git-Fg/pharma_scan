import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:pharma_scan/core/database/providers.dart';
import '../database/daos/app_settings_dao.dart';

part 'app_settings_provider.g.dart';

/// Provider for accessing the AppSettingsDao
@Riverpod(keepAlive: true)
AppSettingsDao appSettingsDao(Ref ref) {
  return ref.watch(databaseProvider()).appSettingsDao;
}

// --- Theme settings providers ---

@riverpod
class ThemeModeNotifier extends _$ThemeModeNotifier {
  @override
  Future<String?> build() => ref.read(appSettingsDaoProvider).themeMode;

  Future<void> setMode(String mode) async {
    await ref.read(appSettingsDaoProvider).setThemeMode(mode);
    // Invalider le state pour provoquer un rechargement
    ref.invalidateSelf();
  }
}

@riverpod
class HapticEnabledNotifier extends _$HapticEnabledNotifier {
  @override
  Future<bool?> build() => ref.read(appSettingsDaoProvider).hapticEnabled;

  Future<void> setEnabled(bool enabled) async {
    await ref.read(appSettingsDaoProvider).setHapticEnabled(enabled);
    ref.invalidateSelf();
  }
}

// --- User preferences providers ---

@riverpod
class UpdateFrequencyNotifier extends _$UpdateFrequencyNotifier {
  @override
  Future<String?> build() => ref.read(appSettingsDaoProvider).updateFrequency;

  Future<void> setFrequency(String frequency) async {
    await ref.read(appSettingsDaoProvider).setUpdateFrequency(frequency);
    state = AsyncData(frequency);
  }
}

@riverpod
class UpdatePolicyNotifier extends _$UpdatePolicyNotifier {
  @override
  Future<String?> build() => ref.read(appSettingsDaoProvider).updatePolicy;

  Future<void> setPolicy(String policy) async {
    await ref.read(appSettingsDaoProvider).setUpdatePolicy(policy);
    state = AsyncData(policy);
  }
}

@riverpod
class PreferredSortingNotifier extends _$PreferredSortingNotifier {
  @override
  Future<String?> build() => ref.read(appSettingsDaoProvider).preferredSorting;

  Future<void> setSorting(String sorting) async {
    await ref.read(appSettingsDaoProvider).setPreferredSorting(sorting);
    state = AsyncData(sorting);
  }
}

@riverpod
class ScanHistoryLimitNotifier extends _$ScanHistoryLimitNotifier {
  @override
  Future<int?> build() => ref.read(appSettingsDaoProvider).scanHistoryLimit;

  Future<void> setLimit(int limit) async {
    await ref.read(appSettingsDaoProvider).setScanHistoryLimit(limit);
    state = AsyncData(limit);
  }
}

// --- Sync metadata providers ---

@riverpod
class LastSyncEpochNotifier extends _$LastSyncEpochNotifier {
  @override
  Future<int?> build() => ref.read(appSettingsDaoProvider).lastSyncEpoch;

  Future<void> setEpoch(int epoch) async {
    await ref.read(appSettingsDaoProvider).setLastSyncEpoch(epoch);
    state = AsyncData(epoch);
  }

  Future<void> updateFromDateTime(DateTime time) async {
    final epoch = time.millisecondsSinceEpoch;
    await setEpoch(epoch);
  }
}

@riverpod
class BdpmVersionNotifier extends _$BdpmVersionNotifier {
  @override
  Future<String?> build() => ref.read(appSettingsDaoProvider).bdpmVersion;

  Future<void> setVersion(String version) async {
    await ref.read(appSettingsDaoProvider).setBdpmVersion(version);
    state = AsyncData(version);
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
  return ref.read(appSettingsDaoProvider).sourceHashes;
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
  return ref.read(appSettingsDaoProvider).sourceDates;
}
