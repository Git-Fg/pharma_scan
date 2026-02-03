import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'app_settings_provider.dart';

part 'theme_provider.g.dart';

enum ThemeSetting { system, light, dark }

ThemeSetting themeSettingFromStorage(String? raw) {
  if (raw == null || raw.isEmpty) {
    return .system;
  }
  return ThemeSetting.values.firstWhere(
    (value) => value.name == raw,
    orElse: () => .system,
  );
}

ThemeSetting themeSettingFromThemeMode(ThemeMode mode) {
  switch (mode) {
    case .light:
      return .light;
    case .dark:
      return .dark;
    case .system:
      return .system;
  }
}

extension ThemeSettingMapper on ThemeSetting {
  ThemeMode get asThemeMode {
    switch (this) {
      case .light:
        return .light;
      case .dark:
        return .dark;
      case .system:
        return .system;
    }
  }
}

@riverpod
ThemeMode theme(Ref ref) {
  final raw = ref.watch(themeModeProvider).value;
  return themeSettingFromStorage(raw).asThemeMode;
}

@riverpod
class ThemeMutation extends _$ThemeMutation {
  @override
  Future<void> build() async {}

  Future<void> setTheme(ThemeSetting setting) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(themeModeProvider.notifier).setMode(setting.name);
      ref.invalidate(themeProvider);
    });
  }
}
