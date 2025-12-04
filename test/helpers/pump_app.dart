// test/helpers/pump_app.dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Test harness for Shadcn UI widgets that require ShadTheme context.
/// This extension provides a reusable way to pump widgets with Shadcn theme configured.
extension PumpApp on WidgetTester {
  /// Pumps a widget wrapped with Shadcn theme and MaterialApp.
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

  /// Pumps a widget with Shadcn theme and AutoRoute router context.
  /// Use this for widgets that require `context.router` (e.g., RoutePage widgets).
  /// For GroupExplorerView, pass a DeepLink with the groupId path.
  /// The widget parameter is ignored - use deepLink to navigate to the route.
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
