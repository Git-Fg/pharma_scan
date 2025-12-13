import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

extension ShadThemeContext on BuildContext {
  // Syntax sugar to access Shad theme pieces.
  ShadThemeData get shadTheme => ShadTheme.of(this);
  ShadTextTheme get shadTextTheme => shadTheme.textTheme;
  ShadColorScheme get shadColors => shadTheme.colorScheme;

  // Native breakpoints from the theme.
  ShadBreakpoints get breakpoints => shadTheme.breakpoints;
}

