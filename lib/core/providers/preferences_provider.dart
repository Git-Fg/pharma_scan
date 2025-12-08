import 'dart:async';

import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preferences_provider.g.dart';

enum SortingPreference {
  princeps,
  generic
  ;

  factory SortingPreference.fromStorage(String value) {
    return switch (value) {
      'generic' => SortingPreference.generic,
      _ => SortingPreference.princeps,
    };
  }

  String get storageValue => switch (this) {
    SortingPreference.princeps => 'princeps',
    SortingPreference.generic => 'generic',
  };
}

@Riverpod(keepAlive: true)
Stream<UpdateFrequency> appPreferences(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.settingsDao.watchSettings().map(
    (AppSetting settings) =>
        UpdateFrequency.fromStorage(settings.updateFrequency),
  );
}

@riverpod
class UpdateFrequencyMutation extends _$UpdateFrequencyMutation {
  @override
  Future<void> build() async {}

  Future<void> setUpdateFrequency(UpdateFrequency newFrequency) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(appDatabaseProvider)
          .settingsDao
          .updateSyncFrequency(newFrequency.storageValue);
    });
  }
}

@riverpod
Stream<bool> hapticSettings(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.settingsDao.watchSettings().map(
    (AppSetting settings) => settings.hapticFeedbackEnabled,
  );
}

@riverpod
class HapticMutation extends _$HapticMutation {
  @override
  Future<void> build() async {}

  Future<void> setEnabled({required bool enabled}) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(appDatabaseProvider)
          .settingsDao
          .updateHapticFeedback(enabled: enabled);
    });
  }
}

@riverpod
Stream<SortingPreference> sortingPreference(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.settingsDao.watchSettings().map(
    (AppSetting settings) =>
        SortingPreference.fromStorage(settings.preferredSorting),
  );
}

@riverpod
Stream<int> scanHistoryLimit(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.settingsDao.watchSettings().map(
    (AppSetting settings) => settings.scanHistoryLimit,
  );
}

@riverpod
class SortingPreferenceMutation extends _$SortingPreferenceMutation {
  @override
  Future<void> build() async {}

  Future<void> setSortingPreference(SortingPreference pref) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(appDatabaseProvider)
          .settingsDao
          .updatePreferredSorting(pref.storageValue);
    });
  }
}
