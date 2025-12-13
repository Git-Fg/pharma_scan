import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferencesProvider', () {
    late ProviderContainer container;
    late PreferencesService preferencesService;

    setUp(() async {
      // Set up mock SharedPreferences with default values
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      preferencesService = PreferencesService(prefs);

      container = ProviderContainer(
        overrides: [
          preferencesServiceProvider.overrideWithValue(preferencesService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('AppPreferences returns default UpdateFrequency', () {
      final frequency = container.read(appPreferencesProvider);

      expect(frequency, isA<UpdateFrequency>());
      expect(frequency, equals(UpdateFrequency.daily));
    });

    test('UpdateFrequencyMutation updates frequency', () async {
      final mutation = container.read(updateFrequencyMutationProvider.notifier);
      await mutation.build();

      await mutation.setUpdateFrequency(UpdateFrequency.weekly);

      // Re-read after invalidation
      final frequency = container.read(appPreferencesProvider);
      expect(frequency, equals(UpdateFrequency.weekly));
    });

    test('hapticSettings returns default value (true)', () {
      final enabled = container.read(hapticSettingsProvider);

      expect(enabled, isA<bool>());
      expect(enabled, isTrue);
    });

    test('HapticMutation updates haptic setting', () async {
      final mutation = container.read(hapticMutationProvider.notifier);
      await mutation.build();

      await mutation.setEnabled(enabled: false);

      // Re-read after invalidation
      final enabled = container.read(hapticSettingsProvider);
      expect(enabled, isFalse);
    });

    test('sortingPreference returns default (princeps)', () {
      final pref = container.read(sortingPreferenceProvider);

      expect(pref, equals(SortingPreference.princeps));
    });

    test('SortingPreferenceMutation updates sorting', () async {
      final mutation = container.read(
        sortingPreferenceMutationProvider.notifier,
      );
      await mutation.build();

      await mutation.setSortingPreference(SortingPreference.generic);

      final pref = container.read(sortingPreferenceProvider);
      expect(pref, equals(SortingPreference.generic));
    });

    test('SortingPreference.name returns correct values', () {
      expect(
        SortingPreference.generic.name,
        equals('generic'),
      );
      expect(
        SortingPreference.princeps.name,
        equals('princeps'),
      );
      expect(
        SortingPreference.form.name,
        equals('form'),
      );
    });

    test('scanHistoryLimit returns default (100)', () {
      final limit = container.read(scanHistoryLimitProvider);

      expect(limit, equals(100));
    });
  });
}
