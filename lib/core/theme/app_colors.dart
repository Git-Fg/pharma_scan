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
  static const Color regulatoryRed = Color(0xFFB91C1C);
  static const Color regulatoryGreen = Color(0xFF15803D);
  static const Color regulatoryGray = Color(0xFF1F2937);
  static const Color regulatoryAmber = Color(0xFFF59E0B);
  static const Color regulatoryPurple = Color(0xFF7C3AED);
  static const Color regulatoryYellow = Color(0xFFFACC15);

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
