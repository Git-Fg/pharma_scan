// lib/core/widgets/ui_kit/badges/standalone_badge.dart
import 'package:flutter/material.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Badge widget for displaying "UNIQUE" label.
/// Used for medications that do not belong to any generic group.
/// Uses muted color scheme to indicate standalone status.
class StandaloneBadge extends StatelessWidget {
  const StandaloneBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadBadge(
      backgroundColor: theme.colorScheme.muted,
      child: Text(
        Strings.badgeStandalone,
        style: theme.textTheme.small.copyWith(
          color: theme.colorScheme.mutedForeground,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
