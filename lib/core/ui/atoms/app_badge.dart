import 'package:flutter/material.dart';
import 'package:pharma_scan/core/ui/atoms/app_text.dart';
import 'package:pharma_scan/core/ui/theme/app_theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum BadgeVariant {
  primary,
  secondary,
  outline,
  destructive,
  success,
  warning,
}

class AppBadge extends StatelessWidget {
  const AppBadge({
    required this.label,
    this.variant = BadgeVariant.primary,
    this.icon,
    super.key,
  });

  final String label;
  final BadgeVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = AppText(label,
        variant: TextVariant.labelSmall, fontWeight: FontWeight.w700);

    return switch (variant) {
      BadgeVariant.primary => ShadBadge(child: text),
      BadgeVariant.secondary => ShadBadge.secondary(child: text),
      BadgeVariant.outline => ShadBadge.outline(child: text),
      BadgeVariant.destructive => ShadBadge.destructive(child: text),
      BadgeVariant.success => ShadBadge(
          backgroundColor: Colors.green.shade100,
          foregroundColor: Colors.green.shade800,
          child: text,
        ),
      BadgeVariant.warning => ShadBadge(
          backgroundColor: Colors.orange.shade100,
          foregroundColor: Colors.orange.shade800,
          child: text,
        ),
    };
  }
}
