// test/helpers/pump_app.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharma_scan/core/theme/pharma_theme_wrapper.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

/// WHY: Test harness for Forui widgets that require FAnimatedTheme context.
/// This extension provides a reusable way to pump widgets with Forui theme configured.
extension PumpApp on WidgetTester {
  /// Pumps a widget wrapped with PharmaThemeWrapper and MaterialApp.
  Future<void> pumpApp(Widget widget) async {
    await pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => PharmaThemeWrapper(
                  updateSystemUi: false, // Avoid side effects in tests
                  child: Scaffold(body: widget),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pumps a widget with Forui theme configuration.
  Future<void> pumpAppWithFullTheme(
    Widget widget, {
    bool isDark = false,
  }) async {
    await pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => PharmaThemeWrapper(
                  themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                  updateSystemUi: false, // Avoid side effects in tests
                  child: Scaffold(body: widget),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
