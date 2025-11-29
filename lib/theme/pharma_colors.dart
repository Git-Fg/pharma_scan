import 'package:flutter/material.dart';

/// Semantic color extension for PharmaScan-specific colors.
///
/// This extension provides app-specific semantic colors (princeps, generic,
/// regulatory colors) that are theme-aware and support light/dark mode.
class PharmaColors extends ThemeExtension<PharmaColors> {
  const PharmaColors({
    required this.princeps,
    required this.generic,
    required this.regulatoryRed,
    required this.regulatoryGreen,
    required this.regulatoryGray,
    required this.regulatoryAmber,
    required this.regulatoryPurple,
    required this.regulatoryYellow,
  });

  /// Princeps medication accent color (replaces AppColors.princepsAccent).
  final Color princeps;

  /// Generic medication accent color (replaces AppColors.genericAccent).
  final Color generic;

  /// Regulatory red color for List 1 medications.
  final Color regulatoryRed;

  /// Regulatory green color for List 2 medications.
  final Color regulatoryGreen;

  /// Regulatory gray color for hospital-only medications.
  final Color regulatoryGray;

  /// Regulatory amber color for restricted medications.
  final Color regulatoryAmber;

  /// Regulatory purple color for exception medications.
  final Color regulatoryPurple;

  /// Regulatory yellow color for surveillance medications.
  final Color regulatoryYellow;

  @override
  ThemeExtension<PharmaColors> copyWith({
    Color? princeps,
    Color? generic,
    Color? regulatoryRed,
    Color? regulatoryGreen,
    Color? regulatoryGray,
    Color? regulatoryAmber,
    Color? regulatoryPurple,
    Color? regulatoryYellow,
  }) {
    return PharmaColors(
      princeps: princeps ?? this.princeps,
      generic: generic ?? this.generic,
      regulatoryRed: regulatoryRed ?? this.regulatoryRed,
      regulatoryGreen: regulatoryGreen ?? this.regulatoryGreen,
      regulatoryGray: regulatoryGray ?? this.regulatoryGray,
      regulatoryAmber: regulatoryAmber ?? this.regulatoryAmber,
      regulatoryPurple: regulatoryPurple ?? this.regulatoryPurple,
      regulatoryYellow: regulatoryYellow ?? this.regulatoryYellow,
    );
  }

  @override
  ThemeExtension<PharmaColors> lerp(
    ThemeExtension<PharmaColors>? other,
    double t,
  ) {
    if (other is! PharmaColors) {
      return this;
    }

    return PharmaColors(
      princeps: Color.lerp(princeps, other.princeps, t)!,
      generic: Color.lerp(generic, other.generic, t)!,
      regulatoryRed: Color.lerp(regulatoryRed, other.regulatoryRed, t)!,
      regulatoryGreen: Color.lerp(regulatoryGreen, other.regulatoryGreen, t)!,
      regulatoryGray: Color.lerp(regulatoryGray, other.regulatoryGray, t)!,
      regulatoryAmber: Color.lerp(regulatoryAmber, other.regulatoryAmber, t)!,
      regulatoryPurple: Color.lerp(
        regulatoryPurple,
        other.regulatoryPurple,
        t,
      )!,
      regulatoryYellow: Color.lerp(
        regulatoryYellow,
        other.regulatoryYellow,
        t,
      )!,
    );
  }
}
