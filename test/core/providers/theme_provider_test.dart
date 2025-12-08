import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider', () {
    late AppDatabase database;
    late ProviderContainer container;

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('themeSettingFromStorage parses values correctly', () {
      expect(
        themeSettingFromStorage('light'),
        equals(ThemeSetting.light),
      );
      expect(
        themeSettingFromStorage('dark'),
        equals(ThemeSetting.dark),
      );
      expect(
        themeSettingFromStorage('system'),
        equals(ThemeSetting.system),
      );
      expect(
        themeSettingFromStorage(null),
        equals(ThemeSetting.system),
      );
      expect(
        themeSettingFromStorage(''),
        equals(ThemeSetting.system),
      );
      expect(
        themeSettingFromStorage('unknown'),
        equals(ThemeSetting.system),
      );
    });

    test('themeSettingFromThemeMode converts correctly', () {
      expect(
        themeSettingFromThemeMode(ThemeMode.light),
        equals(ThemeSetting.light),
      );
      expect(
        themeSettingFromThemeMode(ThemeMode.dark),
        equals(ThemeSetting.dark),
      );
      expect(
        themeSettingFromThemeMode(ThemeMode.system),
        equals(ThemeSetting.system),
      );
    });

    test('ThemeSetting.asThemeMode converts correctly', () {
      expect(
        ThemeSetting.light.asThemeMode,
        equals(ThemeMode.light),
      );
      expect(
        ThemeSetting.dark.asThemeMode,
        equals(ThemeMode.dark),
      );
      expect(
        ThemeSetting.system.asThemeMode,
        equals(ThemeMode.system),
      );
    });

    test('ThemeNotifier emits default theme', () async {
      await database.settingsDao.getSettings();
      final sub = container.listen(themeProvider, (prev, next) {});
      final themeMode = await container.read(themeProvider.future);
      sub.close();

      expect(themeMode, equals(ThemeMode.system));
    });

    test('ThemeMutation updates theme', () async {
      final mutation = container.read(themeMutationProvider.notifier);
      await mutation.build();

      await mutation.setTheme(ThemeSetting.dark);

      final state = container.read(themeMutationProvider);
      expect(state.hasValue, isTrue);

      final settings = await database.settingsDao.getSettings();
      expect(settings.themeMode, equals('dark'));
    });
  });
}
