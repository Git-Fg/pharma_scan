// lib/core/widgets/ui_kit/badges/generic_badge.dart
import 'package:flutter/material.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Badge widget for displaying "GÉNÉRIQUE" label.
/// Uses primary color scheme to distinguish from princeps medications.
class GenericBadge extends StatelessWidget {
  const GenericBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadBadge(
      backgroundColor: theme.colorScheme.primary,
      child: Text(
        Strings.badgeGeneric,
        style: theme.textTheme.small.copyWith(
          color: theme.colorScheme.primaryForeground,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
