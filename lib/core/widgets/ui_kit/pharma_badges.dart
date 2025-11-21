import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PharmaBadges {
  PharmaBadges._();

  static Widget? condition(BuildContext context, String? conditionText) {
    if (conditionText == null || conditionText.isEmpty) return null;
    final theme = ShadTheme.of(context);

    return ShadBadge.outline(
      child: Text(
        conditionText,
        style: theme.textTheme.small.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Widget princeps(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadBadge(
      backgroundColor: theme.colorScheme.secondary,
      child: Text(
        'PRINCEPS',
        style: theme.textTheme.small.copyWith(
          color: theme.colorScheme.secondaryForeground,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  static Widget generic(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadBadge(
      backgroundColor: theme.colorScheme.primary,
      child: Text(
        'GÉNÉRIQUE',
        style: theme.textTheme.small.copyWith(
          color: theme.colorScheme.primaryForeground,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  static Widget standalone(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadBadge(
      backgroundColor: theme.colorScheme.muted,
      child: Text(
        'UNIQUE',
        style: theme.textTheme.small.copyWith(
          color: theme.colorScheme.mutedForeground,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
