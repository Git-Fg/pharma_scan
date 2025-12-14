import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'app_settings_provider.dart';

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
  final raw = ref.watch(themeModeNotifierProvider);
  return themeSettingFromStorage(raw).asThemeMode;
}

@riverpod
class ThemeMutation extends _$ThemeMutation {
  @override
  Future<void> build() async {}

  Future<void> setTheme(ThemeSetting setting) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(themeModeNotifierProvider.notifier).update(setting.name);
      ref.invalidate(themeProvider);
    });
  }
}
