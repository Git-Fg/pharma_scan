import 'package:flutter/material.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title, super.key,
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
    final iconColor = theme.colorScheme.mutedForeground;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppDimens.iconSm, color: iconColor),
            const SizedBox(width: AppDimens.spacingXs),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.h4,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badgeCount != null) ...[
            const SizedBox(width: AppDimens.spacingXs),
            ShadBadge(child: Text('$badgeCount', style: theme.textTheme.small)),
          ],
        ],
      ),
    );
  }
}
