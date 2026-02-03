import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/ui/theme/app_theme.dart';

/// Reusable stat chip displaying a label, value, and icon.
///
/// Used across ScannerResultCard, PrincepsHeroCard, and GroupHeader
/// to display price, refund rate, and other metrics.
class StatChip extends StatelessWidget {
  const StatChip({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
    this.compact = false,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    final spacing = context.spacing;
    final radius = context.radiusMedium;

    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: compact
            ? EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs / 2)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: theme.colorScheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 12 : 14,
              color: theme.colorScheme.mutedForeground,
            ),
            Gap(compact ? 4 : 6),
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
