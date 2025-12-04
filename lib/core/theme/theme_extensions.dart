import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

extension ShadThemeContext on BuildContext {
  ShadThemeData get shadTheme => ShadTheme.of(this);
  ShadTextTheme get shadTextTheme => shadTheme.textTheme;
  ShadColorScheme get shadColors => shadTheme.colorScheme;
  ShadBreakpoints get breakpoints => shadTheme.breakpoints;
}
