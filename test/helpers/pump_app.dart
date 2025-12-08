// test/helpers/pump_app.dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

extension PumpApp on WidgetTester {
  Future<void> pumpApp(Widget widget) async {
    await pumpWidget(
      ProviderScope(
        child: ShadApp.custom(
          theme: ShadThemeData(
            brightness: Brightness.light,
            colorScheme: const ShadSlateColorScheme.light(),
          ),
          darkTheme: ShadThemeData(
            brightness: Brightness.dark,
            colorScheme: const ShadSlateColorScheme.dark(),
          ),
          appBuilder: (BuildContext shadContext) {
            return MaterialApp(
              theme: Theme.of(shadContext),
              darkTheme: Theme.of(shadContext),
              home: Scaffold(body: widget),
              builder: (BuildContext materialContext, Widget? child) {
                return ShadAppBuilder(child: child ?? const SizedBox.shrink());
              },
            );
          },
        ),
      ),
    );
  }

  /// Pumps a widget with Shadcn theme configuration (light or dark).
  /// Uses MaterialApp (not router) for widgets that don't need navigation context.
  Future<void> pumpAppWithFullTheme(
    Widget widget, {
    bool isDark = false,
  }) async {
    await pumpWidget(
      ProviderScope(
        child: ShadApp.custom(
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ShadThemeData(
            brightness: Brightness.light,
            colorScheme: const ShadGreenColorScheme.light(),
          ),
          darkTheme: ShadThemeData(
            brightness: Brightness.dark,
            colorScheme: const ShadGreenColorScheme.dark(),
          ),
          appBuilder: (BuildContext shadContext) {
            return MaterialApp(
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              theme: Theme.of(shadContext),
              darkTheme: Theme.of(shadContext),
              home: Scaffold(body: widget),
              builder: (BuildContext materialContext, Widget? child) {
                return ShadAppBuilder(child: child ?? const SizedBox.shrink());
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> pumpAppWithRouter(
    Widget widget, {
    bool isDark = false,
    DeepLink? deepLink,
  }) async {
    final testRouter = AppRouter();
    await pumpWidget(
      ProviderScope(
        child: ShadApp.custom(
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          theme: ShadThemeData(
            brightness: Brightness.light,
            colorScheme: const ShadGreenColorScheme.light(),
          ),
          darkTheme: ShadThemeData(
            brightness: Brightness.dark,
            colorScheme: const ShadGreenColorScheme.dark(),
          ),
          appBuilder: (BuildContext shadContext) {
            return MaterialApp.router(
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              routerConfig: testRouter.config(
                deepLinkBuilder: deepLink != null ? (_) => deepLink : null,
              ),
              theme: Theme.of(shadContext),
              darkTheme: Theme.of(shadContext),
              builder: (BuildContext materialContext, Widget? child) {
                return ShadAppBuilder(child: child ?? const SizedBox.shrink());
              },
            );
          },
        ),
      ),
    );
  }
}
