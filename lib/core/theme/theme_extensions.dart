import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

extension ShadThemeContext on BuildContext {
  // Syntax sugar to access Shad theme pieces.
  ShadThemeData get shadTheme => ShadTheme.of(this);
  ShadTextTheme get shadTextTheme => shadTheme.textTheme;
  ShadColorScheme get shadColors => shadTheme.colorScheme;

  // Native breakpoints from the theme.
  ShadBreakpoints get breakpoints => shadTheme.breakpoints;
}

extension ShadShortcuts on BuildContext {
  // Theme shortcuts.
  ShadColorScheme get colors => ShadTheme.of(this).colorScheme;
  ShadTextTheme get typo => ShadTheme.of(this).textTheme;

  // Colors.
  Color get primary => colors.primary;
  Color get secondary => colors.secondary;
  Color get destructive => colors.destructive;
  Color get background => colors.background;
  Color get muted => colors.muted;
  Color get border => colors.border;

  // Typography.
  TextStyle get h1 => typo.h1;
  TextStyle get h2 => typo.h2;
  TextStyle get h3 => typo.h3;
  TextStyle get h4 => typo.h4;
  TextStyle get p => typo.p;
  TextStyle get small => typo.small;
  TextStyle get mutedText => typo.muted;

  // Navigation.
  StackRouter get router => AutoRouter.of(this);
}
