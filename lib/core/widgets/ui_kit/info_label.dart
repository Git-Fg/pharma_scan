import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';

class InfoLabel extends StatelessWidget {
  const InfoLabel({
    required this.text, super.key,
    this.icon,
    this.style,
    this.iconColor,
    this.iconSize = AppDimens.iconXs,
    this.maxLines = 1,
  });

  static const double _iconGap = 6; // Widget-specific micro spacing

  final String text;
  final IconData? icon;
  final TextStyle? style;
  final Color? iconColor;
  final double iconSize;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle =
        style ??
        context.shadTextTheme.small.copyWith(
          color: context.shadColors.mutedForeground,
        );
    final effectiveIconColor = iconColor ?? effectiveStyle.color;

    final textWidget = Text(
      text,
      style: effectiveStyle,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );

    if (icon == null) {
      return textWidget;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: effectiveIconColor),
        const Gap(_iconGap),
        Flexible(child: textWidget),
      ],
    );
  }
}
