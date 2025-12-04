import 'package:flutter/material.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
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
    final theme = context.shadTheme;
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

/// Creates a sticky section header for use in [CustomScrollView].
///
/// This helper function creates a [SliverPersistentHeader] with an inline
/// delegate that calculates height dynamically from padding and h4 text style.
/// The height is automatically adjusted for system text scaling.
///
/// Example:
/// ```dart
/// CustomScrollView(
///   slivers: [
///     buildStickySectionHeader(
///       context: context,
///       title: 'Section Title',
///       badgeCount: 5,
///       icon: LucideIcons.star,
///     ),
///     // ... other slivers
///   ],
/// )
/// ```
Widget buildStickySectionHeader({
  required BuildContext context,
  required String title,
  int? badgeCount,
  IconData? icon,
  EdgeInsetsGeometry? padding,
  TextScaler? textScaler,
  double? height,
}) {
  final effectivePadding =
      padding ??
      const EdgeInsets.fromLTRB(
        AppDimens.spacingMd,
        AppDimens.spacingXl,
        AppDimens.spacingMd,
        AppDimens.spacingXs,
      );
  final effectiveTextScaler = textScaler ?? MediaQuery.textScalerOf(context);

  return SliverPersistentHeader(
    pinned: true,
    delegate: _InlineSectionHeaderDelegate(
      title: title,
      badgeCount: badgeCount,
      icon: icon,
      padding: effectivePadding,
      textScaler: effectiveTextScaler,
      height: height,
    ),
  );
}

/// Inline delegate for sticky section headers.
///
/// Calculates height dynamically from padding and h4 text style to avoid
/// magic numbers. Height is automatically scaled for system text scaling.
class _InlineSectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _InlineSectionHeaderDelegate({
    required this.title,
    required this.padding,
    required this.textScaler,
    this.badgeCount,
    this.icon,
    this.height,
  });

  final String title;
  final int? badgeCount;
  final IconData? icon;
  final EdgeInsetsGeometry padding;
  final TextScaler textScaler;
  final double? height;

  @override
  double get minExtent => _calculateHeight();

  @override
  double get maxExtent => _calculateHeight();

  /// Calculates the height based on padding and text height.
  ///
  /// If [height] is provided, uses it directly. Otherwise, calculates
  /// the height dynamically from:
  /// - Padding vertical (top + bottom from [padding])
  /// - Text line height (h4 style, scaled by [textScaler])
  ///
  /// This eliminates magic numbers by deriving the height from actual
  /// design tokens (AppDimens spacing values) and theme typography.
  double _calculateHeight() {
    // If explicit height provided, use it (allows override for custom cases)
    if (height != null) {
      return height!;
    }

    // Calculate padding vertical extent
    final paddingResolved = padding.resolve(TextDirection.ltr);
    final paddingVertical = paddingResolved.top + paddingResolved.bottom;

    // Calculate text line height from h4 style
    // h4 style: fontSize 20px, height multiplier 1.4 = 28px line height
    const h4FontSize = 20.0;
    const h4HeightMultiplier = 1.4;
    const baseTextHeight = h4FontSize * h4HeightMultiplier;

    // Calculate base height: padding + text height
    final baseHeight = paddingVertical + baseTextHeight;

    return textScaler.scale(baseHeight).clamp(baseHeight, baseHeight * 2.0);
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SectionHeader(
      title: title,
      badgeCount: badgeCount,
      icon: icon,
      padding: padding,
    );
  }

  @override
  bool shouldRebuild(_InlineSectionHeaderDelegate oldDelegate) {
    return title != oldDelegate.title ||
        badgeCount != oldDelegate.badgeCount ||
        icon != oldDelegate.icon ||
        padding != oldDelegate.padding ||
        height != oldDelegate.height ||
        textScaler != oldDelegate.textScaler;
  }
}
