import 'dart:async';

import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preferences_provider.g.dart';

enum SortingPreference {
  princeps,
  generic,
  form
  ;

  factory SortingPreference.fromStorage(String value) {
    return switch (value) {
      'generic' => SortingPreference.generic,
      'form' => SortingPreference.form,
      _ => SortingPreference.princeps,
    };
  }

  String get storageValue => switch (this) {
    SortingPreference.princeps => 'princeps',
    SortingPreference.generic => 'generic',
    SortingPreference.form => 'form',
  };
}

// --- Update Frequency ---

@Riverpod(keepAlive: true)
UpdateFrequency appPreferences(Ref ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  final raw = prefs.getString(PrefKeys.updateFrequency);
  return UpdateFrequency.fromStorage(raw ?? 'daily');
}

@riverpod
class UpdateFrequencyMutation extends _$UpdateFrequencyMutation {
  @override
  Future<void> build() async {}

  Future<void> setUpdateFrequency(UpdateFrequency newFrequency) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final prefs = ref.read(preferencesServiceProvider);
      await prefs.setString(
        PrefKeys.updateFrequency,
        newFrequency.storageValue,
      );
      ref.invalidate(appPreferencesProvider);
    });
  }
}

// --- Haptic Feedback ---

@riverpod
bool hapticSettings(Ref ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return prefs.getBool(PrefKeys.hapticEnabled) ?? true;
}

@riverpod
class HapticMutation extends _$HapticMutation {
  @override
  Future<void> build() async {}

  Future<void> setEnabled({required bool enabled}) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() async {
      final prefs = ref.read(preferencesServiceProvider);
      await prefs.setBool(PrefKeys.hapticEnabled, value: enabled);
      ref.invalidate(hapticSettingsProvider);
    });
  }
}

// --- Sorting Preference ---

@riverpod
SortingPreference sortingPreference(Ref ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  final raw = prefs.getString(PrefKeys.preferredSorting);
  return SortingPreference.fromStorage(raw ?? 'princeps');
}

@riverpod
class SortingPreferenceMutation extends _$SortingPreferenceMutation {
  @override
  Future<void> build() async {}

  Future<void> setSortingPreference(SortingPreference pref) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() async {
      final prefs = ref.read(preferencesServiceProvider);
      await prefs.setString(PrefKeys.preferredSorting, pref.storageValue);
      ref.invalidate(sortingPreferenceProvider);
    });
  }
}

// --- Scan History Limit ---

@riverpod
int scanHistoryLimit(Ref ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return prefs.getInt(PrefKeys.scanHistoryLimit) ?? 100;
}
