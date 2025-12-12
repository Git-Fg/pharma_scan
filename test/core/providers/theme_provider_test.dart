import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/providers/theme_provider.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeProvider', () {
    late ProviderContainer container;
    late PreferencesService preferencesService;

    setUp(() async {
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

    test('themeProvider emits default theme (system)', () {
      final themeMode = container.read(themeProvider);
      expect(themeMode, equals(ThemeMode.system));
    });

    test('ThemeMutation updates theme', () async {
      final mutation = container.read(themeMutationProvider.notifier);
      await mutation.build();

      await mutation.setTheme(ThemeSetting.dark);

      // Re-read to verify change
      final themeMode = container.read(themeProvider);
      expect(themeMode, equals(ThemeMode.dark));

      // Verify persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PrefKeys.themeMode), equals('dark'));
    });
  });
}
