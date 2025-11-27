import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:forui/forui.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';

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
                    Text(
                      title,
                      style: context.theme.typography.xl2, // h4 equivalent
                    ),
                    if (description != null) ...[
                      const Gap(AppDimens.spacing2xs),
                      Text(
                        description!,
                        style: context.theme.typography.sm.copyWith(
                          color: context.theme.colors.mutedForeground,
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
                  child: FButton.icon(
                    style: FButtonStyle.ghost(),
                    onPress: onClose,
                    child: const Icon(FIcons.x, size: AppDimens.iconMd),
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
