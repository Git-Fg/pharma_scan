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
}

