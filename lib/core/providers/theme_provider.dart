import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'theme_provider.g.dart';

enum ThemeSetting { system, light, dark }

ThemeSetting themeSettingFromStorage(String? raw) {
  if (raw == null || raw.isEmpty) {
    return ThemeSetting.system;
  }
  return ThemeSetting.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => ThemeSetting.system,
  );
}

ThemeSetting themeSettingFromThemeMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return ThemeSetting.light;
    case ThemeMode.dark:
      return ThemeSetting.dark;
    case ThemeMode.system:
      return ThemeSetting.system;
  }
}

extension ThemeSettingMapper on ThemeSetting {
  ThemeMode get asThemeMode {
    switch (this) {
      case ThemeSetting.light:
        return ThemeMode.light;
      case ThemeSetting.dark:
        return ThemeMode.dark;
      case ThemeSetting.system:
        return ThemeMode.system;
    }
  }
}

@riverpod
ThemeMode theme(Ref ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  final raw = prefs.getString(PrefKeys.themeMode);
  return themeSettingFromStorage(raw).asThemeMode;
}

@riverpod
class ThemeMutation extends _$ThemeMutation {
  @override
  Future<void> build() async {}

  Future<void> setTheme(ThemeSetting setting) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final prefs = ref.read(preferencesServiceProvider);
      await prefs.setString(PrefKeys.themeMode, setting.name);
      ref.invalidate(themeProvider);
    });
  }
}
