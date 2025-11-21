import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.badgeCount,
    this.icon,
    // Standard padding for list headers in this app
    this.padding = const EdgeInsets.fromLTRB(
      AppDimens.spacingMd,
      AppDimens.spacingXl,
      AppDimens.spacingMd,
      AppDimens.spacingXs,
    ),
  });

  final String title;
  final int? badgeCount;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: AppDimens.iconSm,
              color: theme.colorScheme.mutedForeground,
            ),
            const Gap(AppDimens.spacingXs),
          ],
          Text(title, style: theme.textTheme.h4),
          if (badgeCount != null) ...[
            const Gap(AppDimens.spacingXs),
            ShadBadge(
              backgroundColor: theme.colorScheme.muted,
              child: Text(
                '$badgeCount',
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
