import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PharmaSheetLayout extends StatelessWidget {
  const PharmaSheetLayout({
    required this.title, required this.child, super.key,
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
                    Text(title, style: ShadTheme.of(context).textTheme.h4),
                    if (description != null) ...[
                      const Gap(AppDimens.spacing2xs),
                      Text(
                        description!,
                        style: ShadTheme.of(context).textTheme.small.copyWith(
                          color: ShadTheme.of(
                            context,
                          ).colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onClose != null) ...[
                const Gap(AppDimens.spacingMd),
                Semantics(
                  button: true,
                  label: Strings.close,
                  child: ShadIconButton.ghost(
                    onPressed: onClose,
                    icon: const Icon(LucideIcons.x, size: AppDimens.iconMd),
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
