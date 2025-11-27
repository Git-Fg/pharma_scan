import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';

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
    final iconSize = 16.0; // Standard icon size
    final iconColor = context.theme.colors.mutedForeground;
    final gapSize = 8.0; // Standard gap size

    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: iconColor),
            SizedBox(width: gapSize),
          ],
          Expanded(
            child: Text(
              title,
              style: context.theme.typography.xl2, // h4 equivalent
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badgeCount != null) ...[
            SizedBox(width: gapSize),
            FBadge(
              style: FBadgeStyle.primary(),
              child: Text('$badgeCount', style: context.theme.typography.sm),
            ),
          ],
        ],
      ),
    );
  }
}
