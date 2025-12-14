import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../atoms/app_text.dart';
import '../molecules/app_button.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Type de callback pour le bouton de navigation
typedef NavigationCallback = void Function();

/// Widget d'en-tête standardisé
class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.actions = const [],
    this.backgroundColor,
    this.elevation = 0.0,
    this.bottom,
    this.centerTitle = false,
    this.titleSpacing = NavigationToolbar.kMiddleSpacing,
    this.excludeHeaderSemantics = false,
    this.toolbarOpacity = 1.0,
    this.bottomOpacity = 1.0,
    this.showLeadingBackButton = false,
    this.onLeadingPressed,
    this.leadingTooltip,
  });

  /// Constructeur raccourci pour un header avec titre simple
  const AppHeader.title(
    this.title, {
    super.key,
    this.leading,
    this.actions = const [],
    this.backgroundColor,
    this.elevation = 0.0,
    this.bottom,
    this.centerTitle = false,
    this.titleSpacing = NavigationToolbar.kMiddleSpacing,
    this.excludeHeaderSemantics = false,
    this.toolbarOpacity = 1.0,
    this.bottomOpacity = 1.0,
    this.showLeadingBackButton = false,
    this.onLeadingPressed,
    this.leadingTooltip,
    this.titleWidget,
  }) : assert(title != null || titleWidget != null, 'title or titleWidget must be non-null');

  /// Constructeur raccourci pour un header avec widget de titre personnalisé
  const AppHeader.widget(
    this.titleWidget, {
    super.key,
    this.title,
    this.leading,
    this.actions = const [],
    this.backgroundColor,
    this.elevation = 0.0,
    this.bottom,
    this.centerTitle = false,
    this.titleSpacing = NavigationToolbar.kMiddleSpacing,
    this.excludeHeaderSemantics = false,
    this.toolbarOpacity = 1.0,
    this.bottomOpacity = 1.0,
    this.showLeadingBackButton = false,
    this.onLeadingPressed,
    this.leadingTooltip,
  }) : assert(title != null || titleWidget != null, 'title or titleWidget must be non-null');

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget> actions;
  final Color? backgroundColor;
  final double elevation;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;
  final double titleSpacing;
  final bool excludeHeaderSemantics;
  final double toolbarOpacity;
  final double bottomOpacity;
  final bool showLeadingBackButton;
  final NavigationCallback? onLeadingPressed;
  final String? leadingTooltip;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget? leadingWidget;

    if (showLeadingBackButton) {
      leadingWidget = AppButton.icon(
        variant: ButtonVariant.ghost,
        icon: Icons.arrow_back,
        onPressed: onLeadingPressed ?? () => Navigator.maybePop(context),
        tooltip: leadingTooltip ?? 'Retour',
      );
    } else if (leading != null) {
      leadingWidget = leading;
    }

    final titleContent = titleWidget ??
        (title != null
            ? AppText(
                title!,
                variant: TextVariant.headlineSmall,
                fontWeight: FontWeight.w600,
              )
            : null);

    return AppBar(
      backgroundColor: backgroundColor ?? context.surfacePrimary,
      elevation: elevation,
      leading: leadingWidget,
      title: titleContent != null
          ? ExcludeSemantics(
              child: titleContent,
            )
          : null,
      centerTitle: centerTitle,
      titleSpacing: titleSpacing,
      excludeHeaderSemantics: excludeHeaderSemantics,
      toolbarOpacity: toolbarOpacity,
      bottomOpacity: bottomOpacity,
      actions: actions.isEmpty
          ? null
          : [
              ...actions,
              HGap(AppSpacing.medium),
            ],
      bottom: bottom,
    );
  }
}

/// Widget d'en-tête standardisé sans être un AppBar (pour des cas d'utilisation spécifiques)
class AppSimpleHeader extends StatelessWidget {
  const AppSimpleHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.showLeadingBackButton = false,
    this.onLeadingPressed,
    this.backgroundColor,
    this.padding,
    this.centerTitle = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final bool showLeadingBackButton;
  final NavigationCallback? onLeadingPressed;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    Widget? leadingWidget;

    if (showLeadingBackButton) {
      leadingWidget = AppButton.icon(
        variant: ButtonVariant.ghost,
        icon: Icons.arrow_back,
        onPressed: onLeadingPressed ?? () => Navigator.maybePop(context),
      );
    } else if (leading != null) {
      leadingWidget = leading;
    }

    return Container(
      width: double.infinity,
      color: backgroundColor ?? context.surfacePrimary,
      padding: padding ?? EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSpacing.large,
        left: AppSpacing.large,
        right: AppSpacing.large,
        bottom: AppSpacing.large,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leadingWidget != null) ...[
              leadingWidget,
              HGap(AppSpacing.medium),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText(
                    title,
                    variant: TextVariant.headlineSmall,
                    fontWeight: FontWeight.w600,
                  ),
                  if (subtitle != null) ...[
                    Gap(AppSpacing.small),
                    AppText(
                      subtitle!,
                      variant: TextVariant.bodySmall,
                      color: context.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
            if (actions.isNotEmpty) ...[
              HGap(AppSpacing.medium),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...actions,
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}