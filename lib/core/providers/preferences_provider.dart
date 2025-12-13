import 'dart:async';

import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preferences_provider.g.dart';

enum SortingPreference {
  princeps,
  generic,
  form;
}

// --- Update Frequency ---

@Riverpod(keepAlive: true)
UpdateFrequency appPreferences(Ref ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  final raw = prefs.getString(PrefKeys.updateFrequency);
  try {
    return UpdateFrequencyMapper.fromValue(raw);
  } catch (_) {
    return UpdateFrequency.daily;
  }
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
        newFrequency.name, // Utilise la propriété name de l'enum
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
  final raw = prefs.getString(PrefKeys.preferredSorting) ?? 'princeps';
  switch (raw) {
    case 'generic':
      return SortingPreference.generic;
    case 'form':
      return SortingPreference.form;
    default:
      return SortingPreference.princeps;
  }
}

@riverpod
class SortingPreferenceMutation extends _$SortingPreferenceMutation {
  @override
  Future<void> build() async {}

  Future<void> setSortingPreference(SortingPreference pref) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() async {
      final prefs = ref.read(preferencesServiceProvider);
      await prefs.setString(
          PrefKeys.preferredSorting, pref.name); // Utilise la propriété name
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
