import 'package:flutter/material.dart';

/// Extension pour accéder aux couleurs sémantiques
extension SemanticColors on BuildContext {
  // Couleurs de fond
  Color get surfacePrimary => Theme.of(this).colorScheme.surface;
  Color get surfaceSecondary => Theme.of(this).colorScheme.surfaceContainerHighest;
  Color get surfaceTertiary => Theme.of(this).colorScheme.inverseSurface;
  Color get surfacePositive => const Color(0xFFE6F4EA); // Vert pâle
  Color get surfaceWarning => const Color(0xFFFFF4E6); // Orange pâle
  Color get surfaceNegative => const Color(0xFFFCE8E6); // Rouge pâle
  Color get surfaceInfo => const Color(0xFFE8F0FE); // Bleu pâle

  // Couleurs de texte
  Color get textPrimary => Theme.of(this).colorScheme.onSurface;
  Color get textSecondary => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get textMuted => Theme.of(this).colorScheme.onSurface.withValues(alpha: 0.6);
  Color get textPositive => const Color(0xFF137333); // Vert foncé
  Color get textWarning => const Color(0xFFBF5700); // Orange foncé
  Color get textNegative => const Color(0xFFC5221F); // Rouge foncé
  Color get textOnPositive => Colors.white;
  Color get textOnNegative => Colors.white;

  // Couleurs d'action
  Color get actionPrimary => Theme.of(this).colorScheme.primary;
  Color get actionPrimaryContainer => Theme.of(this).colorScheme.primaryContainer;
  Color get actionSecondary => Theme.of(this).colorScheme.secondary;
  Color get actionOnPrimary => Theme.of(this).colorScheme.onPrimary;
  Color get actionOnSecondary => Theme.of(this).colorScheme.onSecondary;
  Color get actionSurface => Theme.of(this).colorScheme.surfaceContainerHighest;
  Color get actionOnSurface => Theme.of(this).colorScheme.onSurfaceVariant;
}

/// Extension pour accéder aux rayons de bord arrondi
extension BorderRadiusTokens on BuildContext {
  BorderRadius get radiusSmall => BorderRadius.circular(4.0);
  BorderRadius get radiusMedium => BorderRadius.circular(8.0);
  BorderRadius get radiusLarge => BorderRadius.circular(12.0);
  BorderRadius get radiusXLarge => BorderRadius.circular(16.0);
  BorderRadius get radiusFull => BorderRadius.circular(9999.0);
}

/// Extension pour accéder aux ombres
extension ShadowTokens on BuildContext {
  List<BoxShadow> get shadowLight => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
  List<BoxShadow> get shadowMedium => [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];
  List<BoxShadow> get shadowHeavy => [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];
}