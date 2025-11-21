import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PharmaBackHeader extends StatelessWidget {
  const PharmaBackHeader({
    super.key,
    required this.title,
    this.description,
    this.trailing,
    this.onBack,
    this.backLabel,
    this.padding = const EdgeInsets.fromLTRB(
      AppDimens.spacingMd,
      AppDimens.spacingMd,
      AppDimens.spacingMd,
      0,
    ),
  });

  static const double _descriptionSpacing = 6.0; // Widget-specific micro gap

  final String title;
  final String? description;
  final Widget? trailing;
  final VoidCallback? onBack;
  final String? backLabel;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                button: true,
                label: backLabel ?? Strings.back,
                child: ShadButton.outline(
                  onPressed: onBack ?? () => context.pop(),
                  leading: const Icon(
                    LucideIcons.arrowLeft,
                    size: AppDimens.iconSm,
                  ),
                  child: const Text(Strings.back),
                ),
              ),
              const Gap(AppDimens.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.h4,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    if (description != null) ...[
                      const Gap(_descriptionSpacing),
                      Text(
                        description!,
                        style: theme.textTheme.muted,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const Gap(AppDimens.spacingSm),
                trailing!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}
