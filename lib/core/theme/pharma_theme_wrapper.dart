// lib/core/theme/pharma_theme_wrapper.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:pharma_scan/theme/theme.dart';

/// WHY: Unified theme wrapper that eliminates duplication between main.dart and test helpers.
/// Handles FAnimatedTheme injection and optional SystemChrome overlay style updates.
class PharmaThemeWrapper extends StatelessWidget {
  const PharmaThemeWrapper({
    required this.child,
    this.themeMode,
    this.updateSystemUi = false,
    super.key,
  });

  final Widget child;
  final ThemeMode? themeMode;
  final bool updateSystemUi;

  @override
  Widget build(BuildContext context) {
    // WHY: Read brightness from Theme.of(context) to determine light/dark theme
    // This works correctly even when themeMode is system (default)
    final brightness = Theme.of(context).brightness;
    final activeForuiTheme =
        brightness == Brightness.dark ? greenDark : greenLight;

    // WHY: Optionally update system UI overlay style for production use
    // Tests should use updateSystemUi: false to avoid side effects
    if (updateSystemUi) {
      final systemUiOverlayStyle = brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark;
      SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
    }

    return FAnimatedTheme(data: activeForuiTheme, child: child);
  }
}
