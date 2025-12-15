import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

extension ShadThemeContext on BuildContext {
  // Access theme data easily: context.shadTheme
  ShadThemeData get shadTheme => ShadTheme.of(this);

  // Access colors: context.colors (TypeScript-like access)
  ShadColorScheme get colors => shadTheme.colorScheme;

  // Access typography: context.typo (TypeScript-like access)
  ShadTextTheme get typo => shadTheme.textTheme;

  // Native breakpoints from the theme.
  ShadBreakpoints get breakpoints => shadTheme.breakpoints;

  // Access spacing tokens: context.spacing
  ShadSpacing get spacing => ShadSpacing.instance;
}

/// Spacing tokens following a standard 4px grid.
///
/// Usage:
/// - Gap(context.spacing.md)
/// - Padding(padding: EdgeInsets.all(context.spacing.lg))
class ShadSpacing {
  static const instance = ShadSpacing._();
  const ShadSpacing._();

  double get xs => 4.0;
  double get sm => 8.0;
  double get md => 16.0;
  double get lg => 24.0;
  double get xl => 32.0;
  double get xxl => 48.0;
}
