import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pharma_scan/core/models/update_frequency.dart';
import 'app_settings_provider.dart';

part 'preferences_provider.g.dart';

/// Sorting preference for restock list display
enum SortingPreference { generic, princeps, form }

// --- Sorting Preference Provider ---

@riverpod
class SortingPreferenceMutation extends _$SortingPreferenceMutation {
  @override
  Future<void> build() async {}

  Future<void> setSortingPreference(SortingPreference preference) async {
    state = const .loading();
    state = await .guard(() async {
      await ref
          .read(preferredSortingProvider.notifier)
          .setSorting(preference.name);
      ref.invalidate(sortingPreferenceProvider);
    });
  }
}

@riverpod
Future<SortingPreference> sortingPreference(Ref ref) async {
  final raw = await ref.watch(preferredSortingProvider.future);
  if (raw == null || raw.isEmpty) {
    return .princeps;
  }
  return SortingPreference.values.firstWhere(
    (e) => e.name == raw,
    orElse: () => .princeps,
  );
}

// --- Haptic Settings Provider ---

@riverpod
class HapticMutation extends _$HapticMutation {
  @override
  Future<void> build() async {}

  Future<void> setEnabled({required bool enabled}) async {
    state = const .loading();
    state = await .guard(() async {
      await ref.read(hapticEnabledProvider.notifier).setEnabled(enabled);
      ref.invalidate(hapticSettingsProvider);
    });
  }
}

@riverpod
Future<bool> hapticSettings(Ref ref) async {
  final enabled = await ref.watch(hapticEnabledProvider.future);
  return enabled ?? true;
}

// --- Update Frequency Provider ---

@riverpod
class UpdateFrequencyMutation extends _$UpdateFrequencyMutation {
  @override
  Future<void> build() async {}

  Future<void> setUpdateFrequency(UpdateFrequency frequency) async {
    state = const .loading();
    state = await .guard(() async {
      await ref
          .read(updateFrequencyProvider.notifier)
          .setFrequency(frequency.name);
      ref.invalidate(appPreferencesProvider);
    });
  }
}

@riverpod
Future<UpdateFrequency> appPreferences(Ref ref) async {
  final raw = await ref.watch(updateFrequencyProvider.future);
  if (raw == null || raw.isEmpty) {
    return .weekly;
  }
  return UpdateFrequency.values.firstWhere(
    (e) => e.name == raw,
    orElse: () => .weekly,
  );
}

// --- Update Policy Provider ---

@riverpod
class UpdatePolicyMutation extends _$UpdatePolicyMutation {
  @override
  Future<void> build() async {}

  Future<void> setPolicy(String policy) async {
    state = const .loading();
    state = await .guard(() async {
      await ref.read(updatePolicyProvider.notifier).setPolicy(policy);
      ref.invalidate(activeUpdatePolicyProvider);
    });
  }
}

@riverpod
Future<String> activeUpdatePolicy(Ref ref) async {
  final raw = await ref.watch(updatePolicyProvider.future);
  return raw ?? 'ask';
}
