// lib/core/widgets/ui_kit/badges/princeps_badge.dart
import 'package:flutter/material.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Badge widget for displaying "PRINCEPS" label.
/// Uses secondary color scheme to distinguish from generic medications.
class PrincepsBadge extends StatelessWidget {
  const PrincepsBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadBadge(
      backgroundColor: theme.colorScheme.secondary,
      child: Text(
        Strings.badgePrinceps,
        style: theme.textTheme.small.copyWith(
          color: theme.colorScheme.secondaryForeground,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
