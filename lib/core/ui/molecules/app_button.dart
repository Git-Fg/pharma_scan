import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../atoms/app_icon.dart';
import '../atoms/app_text.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../../services/haptic_service.dart'; // Assumant que ce service existe

enum ButtonVariant { primary, secondary, destructive, ghost, outline, success, warning }

enum ButtonSize { small, medium, large }

/// Widget de bouton intelligent avec haptique intégrée, gestion du loading et variantes standardisées
class AppButton extends ConsumerWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    this.disabled = false,
    this.tooltip,
    super.key,
  });

  const AppButton.icon({
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    required this.icon,
    this.isLoading = false,
    this.expand = false,
    this.disabled = false,
    this.label,
    this.tooltip,
    super.key,
  });

  final String? label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool expand;
  final bool disabled;
  final String? tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Déterminer si le bouton est activement désactivé (en plus de l'état loading)
    final isDisabled = disabled || isLoading || onPressed == null;
    
    // Gestion de l'haptique
    final haptics = ref.read(hapticServiceProvider);
    
    void handlePress() {
      if (isDisabled) return;
      haptics.selection(); // Feedback tactile systématique
      onPressed!();
    }

    // Calculer les dimensions du bouton selon la taille
    final buttonHeight = switch (size) {
      ButtonSize.small => 32.0,
      ButtonSize.medium => 40.0,
      ButtonSize.large => 48.0,
    };
    
    final iconSize = switch (size) {
      ButtonSize.small => context.iconSizeSmall,
      ButtonSize.medium => context.iconSizeMedium,
      ButtonSize.large => context.iconSizeLarge,
    };
    
    final textVariant = switch (size) {
      ButtonSize.small => TextVariant.labelSmall,
      ButtonSize.medium => TextVariant.labelMedium,
      ButtonSize.large => TextVariant.labelLarge,
    };

    Widget? leadingIcon;
    Widget? trailingContent;
    
    if (isLoading) {
      // Animation de chargement
      leadingIcon = SizedBox(
        width: iconSize,
        height: iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            switch (variant) {
              ButtonVariant.primary => context.actionOnPrimary,
              ButtonVariant.success => context.textOnPositive,
              ButtonVariant.warning => context.textOnNegative,
              _ => context.actionOnSecondary,
            },
          ),
        ),
      );
    } else if (icon != null) {
      // Icône normale
      leadingIcon = AppIcon.custom(
        icon!,
        size: iconSize,
      );
    }

    if (!isLoading && label != null) {
      trailingContent = AppText(
        label!,
        variant: textVariant,
        color: switch (variant) {
          ButtonVariant.primary => context.actionOnPrimary,
          ButtonVariant.secondary => context.actionOnSecondary,
          ButtonVariant.destructive => context.actionOnSecondary,
          ButtonVariant.success => context.textOnPositive,
          ButtonVariant.warning => context.textOnNegative,
          _ => context.actionOnSecondary,
        },
      );
    }

    Widget childWidget;

    if (leadingIcon != null && trailingContent != null) {
      // Icône + texte
      childWidget = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          leadingIcon,
          HGap(AppSpacing.small),
          trailingContent,
        ],
      );
    } else if (leadingIcon != null) {
      // Seulement une icône
      childWidget = leadingIcon;
    } else if (trailingContent != null) {
      // Seulement du texte
      childWidget = trailingContent;
    } else {
      // Bouton vide - devrait pas arriver mais on gère quand même
      childWidget = const SizedBox.shrink();
    }

    // Déterminer les couleurs selon la variante
    final backgroundColor = switch ((variant, isDisabled)) {
      (ButtonVariant.primary, true) || (ButtonVariant.success, true) || (ButtonVariant.warning, true) => context.actionPrimary.withOpacity(0.5),
      (ButtonVariant.primary, false) || (ButtonVariant.success, false) => context.actionPrimary,
      (ButtonVariant.warning, false) => context.textNegative,
      (ButtonVariant.secondary, _) => context.actionSecondary,
      (ButtonVariant.destructive, _) => context.textNegative,
      (ButtonVariant.ghost, true) => Colors.transparent,
      (ButtonVariant.ghost, false) => Colors.transparent,
      (ButtonVariant.outline, true) => Colors.transparent,
      (ButtonVariant.outline, false) => Colors.transparent,
    };

    final borderColor = switch ((variant, isDisabled)) {
      (ButtonVariant.outline, false) => context.actionSurface,
      (ButtonVariant.outline, true) => context.actionSurface.withOpacity(0.5),
      _ => null,
    };


    // Construire le bouton avec les styles appropriés
    Widget buttonWidget = Container(
      height: buttonHeight,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: borderColor != null ? Border.all(color: borderColor) : Border.all(
          color: isDisabled ? context.textMuted : context.actionSurface,
          width: 1.0,
        ),
        borderRadius: context.radiusMedium,
        boxShadow: variant == ButtonVariant.ghost ? [] : context.shadowLight,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : handlePress,
          borderRadius: context.radiusMedium,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: switch (size) {
                ButtonSize.small => AppSpacing.medium,
                ButtonSize.medium => AppSpacing.large,
                ButtonSize.large => AppSpacing.xLarge,
              },
            ),
            child: Center(
              child: childWidget,
            ),
          ),
        ),
      ),
    );

    // Appliquer l'expansion si nécessaire
    if (expand) {
      buttonWidget = SizedBox(
        width: double.infinity,
        child: buttonWidget,
      );
    }

    // Wrap with Tooltip if provided
    if (tooltip != null) {
      buttonWidget = Tooltip(
        message: tooltip!,
        child: buttonWidget,
      );
    }

    return buttonWidget;
  }
}