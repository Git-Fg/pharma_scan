import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeSetting { system, light, dark }

class ThemePreferences {
  static const _themeKey = 'theme_setting';

  static Future<void> setTheme(ThemeSetting setting) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, setting.name);
  }

  static Future<ThemeSetting> getTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themeKey);
    return ThemeSetting.values.firstWhere(
      (value) => value.name == themeName,
      orElse: () => ThemeSetting.system,
    );
  }

  static ThemeMode toThemeMode(ThemeSetting setting) {
    switch (setting) {
      case ThemeSetting.light:
        return ThemeMode.light;
      case ThemeSetting.dark:
        return ThemeMode.dark;
      case ThemeSetting.system:
        return ThemeMode.system;
    }
  }
}
