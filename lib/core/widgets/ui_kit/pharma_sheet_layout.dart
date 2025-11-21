import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PharmaSheetLayout extends StatelessWidget {
  const PharmaSheetLayout({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.onClose,
    this.padding = const EdgeInsets.all(AppDimens.spacingLg),
  });

  final String title;
  final String? description;
  final Widget child;
  final VoidCallback? onClose;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Standardisé
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.h4),
                    if (description != null) ...[
                      const Gap(AppDimens.spacing2xs),
                      Text(description!, style: theme.textTheme.muted),
                    ],
                  ],
                ),
              ),
              if (onClose != null) ...[
                const Gap(AppDimens.spacingMd),
                Semantics(
                  button: true,
                  label: Strings.close,
                  child: ShadButton.ghost(
                    onPressed: onClose,
                    child: const Icon(LucideIcons.x, size: AppDimens.iconMd),
                  ),
                ),
              ],
            ],
          ),
          const Gap(AppDimens.spacingXl),
          // Contenu
          Flexible(child: child),
        ],
      ),
    );
  }
}
