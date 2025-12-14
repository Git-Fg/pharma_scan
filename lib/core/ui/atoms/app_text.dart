import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Variante de texte standardisée
enum TextVariant {
  displayLarge,
  displayMedium,
  displaySmall,
  headlineLarge,
  headlineMedium,
  headlineSmall,
  titleLarge,
  titleMedium,
  titleSmall,
  labelLarge,
  labelMedium,
  labelSmall,
  bodyLarge,
  bodyMedium,
  bodySmall,
  bodyExtraSmall,
}

/// Extension sur BuildContext pour accéder facilement aux variantes de texte
extension TypographyExtension on BuildContext {
  TextStyle get displayLarge => Theme.of(this).textTheme.displayLarge!.copyWith(
        color: textPrimary,
      );
  TextStyle get displayMedium => Theme.of(this).textTheme.displayMedium!.copyWith(
        color: textPrimary,
      );
  TextStyle get displaySmall => Theme.of(this).textTheme.displaySmall!.copyWith(
        color: textPrimary,
      );
  TextStyle get headlineLarge => Theme.of(this).textTheme.headlineLarge!.copyWith(
        color: textPrimary,
      );
  TextStyle get headlineMedium => Theme.of(this).textTheme.headlineMedium!.copyWith(
        color: textPrimary,
      );
  TextStyle get headlineSmall => Theme.of(this).textTheme.headlineSmall!.copyWith(
        color: textPrimary,
      );
  TextStyle get titleLarge => Theme.of(this).textTheme.titleLarge!.copyWith(
        color: textPrimary,
      );
  TextStyle get titleMedium => Theme.of(this).textTheme.titleMedium!.copyWith(
        color: textPrimary,
      );
  TextStyle get titleSmall => Theme.of(this).textTheme.titleSmall!.copyWith(
        color: textPrimary,
      );
  TextStyle get labelLarge => Theme.of(this).textTheme.labelLarge!.copyWith(
        color: textPrimary,
      );
  TextStyle get labelMedium => Theme.of(this).textTheme.labelMedium!.copyWith(
        color: textPrimary,
      );
  TextStyle get labelSmall => Theme.of(this).textTheme.labelSmall!.copyWith(
        color: textPrimary,
      );
  TextStyle get bodyLarge => Theme.of(this).textTheme.bodyLarge!.copyWith(
        color: textPrimary,
      );
  TextStyle get bodyMedium => Theme.of(this).textTheme.bodyMedium!.copyWith(
        color: textPrimary,
      );
  TextStyle get bodySmall => Theme.of(this).textTheme.bodySmall!.copyWith(
        color: textPrimary,
      );
  TextStyle get bodyExtraSmall => Theme.of(this).textTheme.bodySmall!.copyWith(
        color: textPrimary,
        fontSize: 12,
      );
}

/// Widget de texte standardisé
class AppText extends StatelessWidget {
  const AppText(
    String? this.data, {
    super.key,
    this.variant = TextVariant.bodyMedium,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.fontSize,
    this.height,
    this.textStyle,
    this.semanticsLabel,
  }) : child = null, textSpan = null;

  const AppText.rich(
    TextSpan? this.textSpan, {
    super.key,
    this.variant = TextVariant.bodyMedium,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.fontSize,
    this.height,
    this.textStyle,
    this.semanticsLabel,
  }) : child = null, data = null;

  const AppText.child(
    Widget? this.child, {
    super.key,
    this.variant = TextVariant.bodyMedium,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fontWeight,
    this.fontSize,
    this.height,
    this.textStyle,
    this.semanticsLabel,
  }) : data = null, textSpan = null;

  final String? data;
  final TextSpan? textSpan;
  final Widget? child;
  final TextVariant variant;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final FontWeight? fontWeight;
  final double? fontSize;
  final double? height;
  final TextStyle? textStyle;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    late final TextStyle baseStyle;

    // Déterminer le style de base selon la variante
    baseStyle = switch (variant) {
      TextVariant.displayLarge => context.displayLarge,
      TextVariant.displayMedium => context.displayMedium,
      TextVariant.displaySmall => context.displaySmall,
      TextVariant.headlineLarge => context.headlineLarge,
      TextVariant.headlineMedium => context.headlineMedium,
      TextVariant.headlineSmall => context.headlineSmall,
      TextVariant.titleLarge => context.titleLarge,
      TextVariant.titleMedium => context.titleMedium,
      TextVariant.titleSmall => context.titleSmall,
      TextVariant.labelLarge => context.labelLarge,
      TextVariant.labelMedium => context.labelMedium,
      TextVariant.labelSmall => context.labelSmall,
      TextVariant.bodyLarge => context.bodyLarge,
      TextVariant.bodyMedium => context.bodyMedium,
      TextVariant.bodySmall => context.bodySmall,
      TextVariant.bodyExtraSmall => context.bodyExtraSmall,
    };

    // Appliquer les modifications personnalisées
    var finalStyle = baseStyle.copyWith(
      color: color,
      fontWeight: fontWeight,
      fontSize: fontSize,
      height: height,
    );

    // Fusionner avec le textStyle si fourni
    if (textStyle != null) {
      finalStyle = finalStyle.merge(textStyle);
    }

    if (child != null) {
      return Semantics(
        label: semanticsLabel,
        child: DefaultTextStyle(
          style: finalStyle,
          child: child!,
        ),
      );
    } else if (textSpan != null) {
      return Semantics(
        label: semanticsLabel,
        child: Text.rich(
          textSpan!,
          style: finalStyle,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        ),
      );
    } else {
      return Semantics(
        label: semanticsLabel,
        child: Text(
          data!,
          style: finalStyle,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        ),
      );
    }
  }
}