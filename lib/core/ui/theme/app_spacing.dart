import 'package:flutter/material.dart';

/// Constantes d'espacement standardisées
class AppSpacing {
  // Espacements de base
  static const double base = 4.0;
  static const double small = base * 1;      // 4dp
  static const double medium = base * 2;     // 8dp
  static const double large = base * 3;      // 12dp
  static const double xLarge = base * 4;     // 16dp
  static const double xxLarge = base * 6;    // 24dp
  static const double xxxLarge = base * 8;   // 32dp
  static const double xxxxLarge = base * 12; // 48dp
  static const double xxxxxLarge = base * 16; // 64dp
}

/// Widget pour ajouter un espace vertical standardisé
class Gap extends StatelessWidget {
  const Gap(this.height, {super.key});
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height);
  }
}

/// Widget pour ajouter un espace horizontal standardisé
class HGap extends StatelessWidget {
  const HGap(this.width, {super.key});
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width);
  }
}

/// Extension sur BuildContext pour accéder facilement aux espacements
extension SpacingExtension on BuildContext {
  double get gapSmall => AppSpacing.small;
  double get gapMedium => AppSpacing.medium;
  double get gapLarge => AppSpacing.large;
  double get gapXLarge => AppSpacing.xLarge;
  double get gapXXLarge => AppSpacing.xxLarge;
  double get gapXXXLarge => AppSpacing.xxxLarge;
  double get gapXXXXLarge => AppSpacing.xxxxLarge;
  double get gapXXXXXLarge => AppSpacing.xxxxxLarge;
}