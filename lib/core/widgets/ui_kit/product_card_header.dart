import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';

/// Atom widget for product card title row.
///
/// Displays badges, title, status icons, and optional trailing widget.
/// Used by both ScannerResultCard and other product card variants.
class ProductCardHeader extends StatelessWidget {
  const ProductCardHeader({
    required this.displayTitle,
    required this.badges,
    required this.statusIcons,
    required this.isFocusPrinceps,
    required this.compact,
    this.trailing,
    super.key,
  });

  final String displayTitle;
  final List<Widget> badges;
  final Widget statusIcons;
  final bool isFocusPrinceps;
  final bool compact;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    final baseTitleStyle = theme.textTheme.h4;
    final titleStyle = compact
        ? theme.textTheme.p.copyWith(fontWeight: FontWeight.w600)
        : baseTitleStyle.copyWith(
            fontWeight: isFocusPrinceps
                ? FontWeight.bold
                : baseTitleStyle.fontWeight,
            letterSpacing: isFocusPrinceps
                ? -0.5
                : baseTitleStyle.letterSpacing,
          );
    return Padding(
      padding: EdgeInsets.all(
        compact ? AppDimens.spacing2xs : AppDimens.spacingMd,
      ),
      child: Row(
        children: [
          if (badges.isNotEmpty) ...[
            ...badges.map(
              (badge) => Padding(
                padding: EdgeInsets.only(
                  right: compact ? 4.0 : AppDimens.spacingXs,
                ),
                child: badge,
              ),
            ),
            Gap(compact ? 4.0 : AppDimens.spacingXs),
          ],
          Expanded(
            child: Text(
              displayTitle,
              style: titleStyle,
              overflow: TextOverflow.ellipsis,
              maxLines: compact ? 1 : 2,
            ),
          ),
          if (statusIcons is! SizedBox) ...[
            Gap(compact ? 4.0 : AppDimens.spacingXs),
            statusIcons,
          ],
          if (trailing != null) ...[
            Gap(compact ? 4.0 : AppDimens.spacingXs),
            trailing!,
          ],
        ],
      ),
    );
  }
}
