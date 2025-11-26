import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Global color tokens used across PharmaScan to keep the visual language
/// consistent without introducing a heavy theme abstraction layer.
class AppColors {
  AppColors._();

  static const String princepsKey = 'princeps';
  static const String genericKey = 'generic';

  static const Color scaffoldOffWhite = Color(0xFFF8FAFC);
  static const Color scaffoldSlateDark = Color(0xFF0F172A);

  static const Color princepsAccent = Color(0xFF4338CA);
  static const Color genericAccent = Color(0xFF0D9488);

  static const Map<String, Color> semanticCustomColors = {
    princepsKey: princepsAccent,
    genericKey: genericAccent,
  };
}

extension AppSemanticColors on ShadColorScheme {
  Color get princeps =>
      custom[AppColors.princepsKey] ?? AppColors.princepsAccent;
  Color get generic => custom[AppColors.genericKey] ?? AppColors.genericAccent;
}
