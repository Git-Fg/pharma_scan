import 'package:flutter/material.dart';

/// Global color tokens used across PharmaScan to keep the visual language
/// consistent without introducing a heavy theme abstraction layer.
class AppColors {
  AppColors._();

  static const String princepsKey = 'princeps';
  static const String genericKey = 'generic';

  // Scaffold colors
  static const Color scaffoldOffWhite = Color(0xFFF8FAFC);
  static const Color scaffoldSlateDark = Color(0xFF0F172A);

  // Semantic colors (app-specific)
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

  /// Returns color scheme for light mode (Zinc-based)
  /// Based on Forui color scheme
  static Map<String, Color> getLightColors() {
    return {
      // Primary colors
      'primary': const Color(0xFF09090B),
      'primaryForeground': const Color(0xFFFAFAFA),
      // Secondary colors
      'secondary': const Color(0xFF3F3F46),
      'secondaryForeground': const Color(0xFFFAFAFA),
      // Background and foreground
      'background': const Color(0xFFFFFFFF),
      'foreground': const Color(0xFF09090B),
      // Muted colors
      'muted': const Color(0xFFF4F4F5),
      'mutedForeground': const Color(0xFF71717A),
      // Card colors
      'card': const Color(0xFFFFFFFF),
      'cardForeground': const Color(0xFF09090B),
      // Border and ring
      'border': const Color(0xFFF4F4F5),
      'ring': const Color(0xFF09090B),
      // Destructive colors
      'destructive': const Color(0xFFEF4444),
      'destructiveForeground': const Color(0xFFFAFAFA),
    };
  }

  /// Returns color scheme for dark mode (Slate-based)
  /// Based on Forui color scheme
  static Map<String, Color> getDarkColors() {
    return {
      // Primary colors
      'primary': const Color(0xFF0F172A),
      'primaryForeground': const Color(0xFFF1F5F9),
      // Secondary colors
      'secondary': const Color(0xFF1E293B),
      'secondaryForeground': const Color(0xFFF1F5F9),
      // Background and foreground
      'background': const Color(0xFF111827),
      'foreground': const Color(0xFFE0E7FF),
      // Muted colors
      'muted': const Color(0xFF475569),
      'mutedForeground': const Color(0xFF94A3B8),
      // Card colors
      'card': const Color(0xFF1E293B),
      'cardForeground': const Color(0xFFE0E7FF),
      // Border and ring
      'border': const Color(0xFF334155),
      'ring': const Color(0xFF475569),
      // Destructive colors
      'destructive': const Color(0xFFEF4444),
      'destructiveForeground': const Color(0xFFF1F5F9),
    };
  }
}
