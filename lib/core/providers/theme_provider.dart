import 'package:flutter/material.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
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
class ThemeNotifier extends _$ThemeNotifier {
  @override
  Stream<ThemeMode> build() {
    final db = ref.watch(appDatabaseProvider);
    return db.settingsDao.watchSettings().map(
      (settings) => themeSettingFromStorage(settings.themeMode).asThemeMode,
    );
  }
}

@riverpod
class ThemeMutation extends _$ThemeMutation {
  @override
  Future<void> build() async {}

  Future<void> setTheme(ThemeSetting setting) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final updateEither = await ref
          .read(appDatabaseProvider)
          .settingsDao
          .updateTheme(setting.name);
      return updateEither.fold<Future<void>>(
        ifLeft: Future<void>.error,
        ifRight: (_) => Future<void>.value(),
      );
    });
  }
}
