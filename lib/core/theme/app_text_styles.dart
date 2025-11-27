import 'package:flutter/material.dart';

/// Text styles for the PharmaScan design system.
/// Based on Forui typography scale.
class AppTextStyles {
  AppTextStyles._();

  /// Creates text styles matching Forui typography scale.
  /// h3 and h4 have custom font weights as configured in main.dart.
  static Map<String, TextStyle> getTextStyles() {
    return {
      'h1': const TextStyle(
        fontSize: 36, // text-4xl (2.25rem)
        fontWeight: FontWeight.bold,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      'h2': const TextStyle(
        fontSize: 30, // text-3xl (1.875rem)
        fontWeight: FontWeight.bold,
        height: 1.3,
        letterSpacing: -0.5,
      ),
      'h3': const TextStyle(
        fontSize: 24, // text-2xl (1.5rem)
        fontWeight: FontWeight.w700, // Custom weight as in main.dart
        height: 1.4,
        letterSpacing: 0,
      ),
      'h4': const TextStyle(
        fontSize: 20, // text-xl (1.25rem)
        fontWeight: FontWeight.w600, // Custom weight as in main.dart
        height: 1.5,
        letterSpacing: 0,
      ),
      'p': const TextStyle(
        fontSize: 16, // text-base (1rem)
        fontWeight: FontWeight.normal,
        height: 1.5,
        letterSpacing: 0,
      ),
      'small': const TextStyle(
        fontSize: 14, // text-sm (0.875rem)
        fontWeight: FontWeight.normal,
        height: 1.5,
        letterSpacing: 0,
      ),
      'muted': const TextStyle(
        fontSize: 14, // text-sm (0.875rem)
        fontWeight: FontWeight.normal,
        height: 1.5,
        letterSpacing: 0,
      ),
    };
  }
}

