import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Enumération des variantes de carte
enum CardVariant { 
  elevated,    // Carte avec ombre
  filled,      // Carte avec couleur de fond
  outlined,    // Carte avec bordure seulement
  ghost        // Carte transparente avec bordure subtile
}

/// Widget de carte standardisée
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.variant = CardVariant.elevated,
    this.margin,
    this.padding,
    this.color,
    this.borderColor,
    this.borderRadius,
    this.elevation,
    this.clipBehavior,
    this.shape,
  });

  final Widget child;
  final CardVariant variant;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;
  final BorderRadiusGeometry? borderRadius;
  final double? elevation;
  final Clip? clipBehavior;
  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) {
    // Déterminer les styles selon la variante
    final cardColor = color ?? switch (variant) {
      CardVariant.filled => context.surfaceSecondary,
      CardVariant.ghost => Colors.transparent,
      _ => context.surfacePrimary,
    };

    final computedBorderColor = borderColor ?? switch (variant) {
      CardVariant.outlined || CardVariant.ghost => context.actionSurface,
      _ => null,
    };

    final computedBorderRadius = borderRadius ?? context.radiusMedium;
    final computedElevation = elevation ?? switch (variant) {
      CardVariant.elevated => 2.0,
      _ => 0.0,
    };

    final computedPadding = padding ?? const EdgeInsets.all(16.0);

    Widget cardWidget = Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: computedBorderRadius,
        border: computedBorderColor != null 
          ? Border.all(color: computedBorderColor) 
          : null,
        boxShadow: variant == CardVariant.elevated 
          ? context.shadowLight 
          : [],
      ),
      child: ClipRRect(
        borderRadius: computedBorderRadius,
        clipBehavior: clipBehavior ?? Clip.hardEdge,
        child: Padding(
          padding: computedPadding,
          child: child,
        ),
      ),
    );

    // Si une shape spéciale est fournie, utiliser Card directement
    if (shape != null) {
      cardWidget = Card(
        margin: margin,
        color: cardColor,
        elevation: computedElevation,
        shape: shape,
        clipBehavior: clipBehavior,
        child: Padding(
          padding: computedPadding,
          child: child,
        ),
      );
    }

    // Ajouter la marge extérieure si spécifiée
    if (margin != null) {
      cardWidget = Container(
        margin: margin,
        child: cardWidget,
      );
    }

    return cardWidget;
  }
}