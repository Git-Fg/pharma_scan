import 'package:flutter/material.dart';

import 'package:pharma_scan/core/config/app_config.dart' as config;

/// Semantic color constants for brand-specific colors
/// These define the app's semantic color palette for status and feedback
abstract final class _SemanticColorTokens {
  static const surfacePositive = Color(0xFFE6F4EA);
  static const surfaceWarning = Color(0xFFFFF4E6);
  static const surfaceNegative = Color(0xFFFCE8E6);
  static const surfaceInfo = Color(0xFFE8F0FE);
  static const textPositive = Color(0xFF137333);
  static const textWarning = Color(0xFFBF5700);
  static const textNegative = Color(0xFFC5221F);
}

/// Extension pour accéder aux couleurs sémantiques
extension SemanticColors on BuildContext {
  // Couleurs de fond
  Color get surfacePrimary => Theme.of(this).colorScheme.surface;
  Color get surfaceSecondary =>
      Theme.of(this).colorScheme.surfaceContainerHighest;
  Color get surfaceTertiary => Theme.of(this).colorScheme.inverseSurface;
  Color get surfacePositive => _SemanticColorTokens.surfacePositive;
  Color get surfaceWarning => _SemanticColorTokens.surfaceWarning;
  Color get surfaceNegative => _SemanticColorTokens.surfaceNegative;
  Color get surfaceInfo => _SemanticColorTokens.surfaceInfo;

  // Couleurs de texte
  Color get textPrimary => Theme.of(this).colorScheme.onSurface;
  Color get textSecondary => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get textMuted =>
      Theme.of(this).colorScheme.onSurface.withValues(alpha: 0.6);
  Color get textPositive => _SemanticColorTokens.textPositive;
  Color get textWarning => _SemanticColorTokens.textWarning;
  Color get textNegative => _SemanticColorTokens.textNegative;
  Color get textOnPositive => Colors.white;
  Color get textOnNegative => Colors.white;

  // Couleurs d'action
  Color get actionPrimary => Theme.of(this).colorScheme.primary;
  Color get actionPrimaryContainer =>
      Theme.of(this).colorScheme.primaryContainer;
  Color get actionSecondary => Theme.of(this).colorScheme.secondary;
  Color get actionOnPrimary => Theme.of(this).colorScheme.onPrimary;
  Color get actionOnSecondary => Theme.of(this).colorScheme.onSecondary;
  Color get actionSurface => Theme.of(this).colorScheme.surfaceContainerHighest;
  Color get actionOnSurface => Theme.of(this).colorScheme.onSurfaceVariant;
}

/// Extension pour accéder aux rayons de bord arrondi
extension BorderRadiusTokens on BuildContext {
  BorderRadius get radiusSmall => .circular(4.0);
  BorderRadius get radiusMedium => .circular(8.0);
  BorderRadius get radiusLarge => .circular(12.0);
  BorderRadius get radiusXLarge => .circular(16.0);
  BorderRadius get radiusFull => .circular(config.UiSizes.radiusFull);
}

/// Extension pour accéder aux ombres
extension ShadowTokens on BuildContext {
  List<BoxShadow> get shadowLight => [
    BoxShadow(
      color: Theme.of(this).colorScheme.surface.withValues(alpha: 0.1),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
  List<BoxShadow> get shadowMedium => [
    BoxShadow(
      color: Theme.of(this).colorScheme.surface.withValues(alpha: 0.1),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  List<BoxShadow> get shadowHeavy => [
    BoxShadow(
      color: Theme.of(this).colorScheme.surface.withValues(alpha: 0.15),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];
}
