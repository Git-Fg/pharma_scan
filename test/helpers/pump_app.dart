// test/helpers/pump_app.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:forui/forui.dart';
import 'package:pharma_scan/theme/theme.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

/// WHY: Test harness for Forui widgets that require FAnimatedTheme context.
/// This extension provides a reusable way to pump widgets with Forui theme configured.
extension PumpApp on WidgetTester {
  /// Pumps a widget wrapped with FAnimatedTheme and MaterialApp.
  Future<void> pumpApp(Widget widget) async {
    await pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => FAnimatedTheme(
                  data: greenLight,
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
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => FAnimatedTheme(
                  data: greenLight, // TODO: Add dark theme support
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
