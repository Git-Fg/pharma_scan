import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:forui/forui.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';

class InfoLabel extends StatelessWidget {
  const InfoLabel({
    super.key,
    required this.text,
    this.icon,
    this.style,
    this.iconColor,
    this.iconSize = AppDimens.iconXs,
    this.maxLines = 1,
  });

  static const double _iconGap = 6.0; // Widget-specific micro spacing

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
        context.theme.typography.sm.copyWith(
          color: context.theme.colors.mutedForeground,
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: iconSize, color: effectiveIconColor),
        const Gap(_iconGap),
        Flexible(child: textWidget),
      ],
    );
  }
}
