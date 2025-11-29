import 'package:flutter/material.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/widgets/ui_kit/section_header.dart';

/// Delegate for creating sticky section headers in Sliver lists.
///
/// This delegate extends [SliverPersistentHeaderDelegate] to provide
/// a consistent header appearance that matches [SectionHeader] widget.
/// Use with [SliverPersistentHeader] and set `pinned: true` for sticky behavior.
class SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  /// Creates a delegate for a section header.
  ///
  /// [title] is required and will be displayed as the header text.
  /// [badgeCount] is optional and will display a badge with the count.
  /// [icon] is optional and will display an icon before the title.
  /// [padding] defaults to the standard section header padding.
  /// [height] is optional and defaults to [AppDimens.headerHeight].
  ///   If provided, this value will be used directly instead of calculating
  ///   from padding and typography. Useful for custom headers or when
  ///   system text scaling requires a different height.
  /// [textScaler] is optional and defaults to [TextScaler.noScaling].
  ///   Used to calculate dynamic height based on OS-level font scaling to
  ///   prevent content clipping in sticky headers.
  const SectionHeaderDelegate({
    required this.title,
    this.badgeCount,
    this.icon,
    this.padding = const EdgeInsets.fromLTRB(
      AppDimens.spacingMd,
      AppDimens.spacingXl,
      AppDimens.spacingMd,
      AppDimens.spacingXs,
    ),
    this.height,
    this.textScaler = TextScaler.noScaling,
  });

  final String title;
  final int? badgeCount;
  final IconData? icon;
  final EdgeInsetsGeometry padding;
  final double? height;
  final TextScaler textScaler;

  @override
  double get minExtent => _calculateHeight();

  @override
  double get maxExtent => _calculateHeight();

  /// Calculates the height based on padding and text height.
  ///
  /// If [height] is provided, uses it directly. Otherwise, scales
  /// [AppDimens.headerHeight] based on [textScaler] to respond to OS-level
  /// font scaling. The scaled height is capped at 2.0x to prevent excessive
  /// header growth.
  ///
  /// [AppDimens.headerHeight] is calculated based on actual measured content:
  /// - Standard padding (top: 24px + bottom: 8px = 32px)
  /// - xl2 typography line height (fontSize 22px × height 2.0 = 44px, actual measured)
  /// - Small buffer for system text scaling (4px)
  /// Total: 80px
  ///
  /// This value must match or slightly exceed the actual content height to avoid
  /// "layoutExtent exceeds paintExtent" errors in SliverPersistentHeader.
  double _calculateHeight() {
    // If explicit height provided, use it (allows override for custom cases)
    if (height != null) {
      return height!;
    }

    // Scale the base height based on text scale factor
    // We cap it at 2.0x to prevent excessive header growth
    return textScaler
        .scale(AppDimens.headerHeight)
        .clamp(AppDimens.headerHeight, AppDimens.headerHeight * 2.0);
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
  bool shouldRebuild(SectionHeaderDelegate oldDelegate) {
    return title != oldDelegate.title ||
        badgeCount != oldDelegate.badgeCount ||
        icon != oldDelegate.icon ||
        padding != oldDelegate.padding ||
        height != oldDelegate.height ||
        textScaler != oldDelegate.textScaler;
  }
}
