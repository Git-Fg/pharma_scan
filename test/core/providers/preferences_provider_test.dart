import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferencesProvider', () {
    late AppDatabase database;
    late ProviderContainer container;

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('AppPreferences emits default UpdateFrequency', () async {
      await database.settingsDao.getSettings();
      final sub = container.listen(appPreferencesProvider, (prev, next) {});
      final frequency = await container.read(appPreferencesProvider.future);
      sub.close();

      expect(frequency, isA<UpdateFrequency>());
      expect(frequency, equals(UpdateFrequency.daily));
    });

    test('UpdateFrequencyMutation updates frequency', () async {
      final mutation = container.read(updateFrequencyMutationProvider.notifier);
      await mutation.build();

      await mutation.setUpdateFrequency(UpdateFrequency.daily);

      final state = container.read(updateFrequencyMutationProvider);
      expect(state.hasValue, isTrue);

      final settings = await database.settingsDao.getSettings();
      expect(settings.updateFrequency, equals('daily'));
    });

    test('hapticSettings emits default value', () async {
      await database.settingsDao.getSettings();
      final sub = container.listen(hapticSettingsProvider, (prev, next) {});
      final enabled = await container.read(hapticSettingsProvider.future);
      sub.close();

      expect(enabled, isA<bool>());
      expect(enabled, isTrue);
    });

    test('HapticMutation updates haptic setting', () async {
      final mutation = container.read(hapticMutationProvider.notifier);
      await mutation.build();

      await mutation.setEnabled(enabled: false);

      final state = container.read(hapticMutationProvider);
      expect(state.hasValue, isTrue);

      final settings = await database.settingsDao.getSettings();
      expect(settings.hapticFeedbackEnabled, isFalse);
    });

    test('SortingPreference.fromStorage parses values correctly', () {
      expect(
        SortingPreference.fromStorage('generic'),
        equals(SortingPreference.generic),
      );
      expect(
        SortingPreference.fromStorage('princeps'),
        equals(SortingPreference.princeps),
      );
      expect(
        SortingPreference.fromStorage('unknown'),
        equals(SortingPreference.princeps),
      );
    });

    test('SortingPreference.storageValue returns correct string', () {
      expect(
        SortingPreference.generic.storageValue,
        equals('generic'),
      );
      expect(
        SortingPreference.princeps.storageValue,
        equals('princeps'),
      );
    });
  });
}
