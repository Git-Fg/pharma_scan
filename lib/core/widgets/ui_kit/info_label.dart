import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    final theme = ShadTheme.of(context);
    final effectiveStyle = style ?? theme.textTheme.muted;
    final effectiveIconColor = iconColor ?? effectiveStyle.color;

    if (icon == null) {
      return Text(
        text,
        style: effectiveStyle,
        overflow: TextOverflow.ellipsis,
        maxLines: maxLines,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: iconSize, color: effectiveIconColor),
        const Gap(_iconGap),
        Flexible(
          child: Text(
            text,
            style: effectiveStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: maxLines,
          ),
        ),
      ],
    );
  }
}
