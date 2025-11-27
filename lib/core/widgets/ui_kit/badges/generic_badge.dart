// lib/core/widgets/ui_kit/badges/generic_badge.dart
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:pharma_scan/core/utils/strings.dart';

/// Badge widget for displaying "GÉNÉRIQUE" label.
/// Uses primary color scheme to distinguish from princeps medications.
class GenericBadge extends StatelessWidget {
  const GenericBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.theme.colors.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        Strings.badgeGeneric,
        style: context.theme.typography.sm.copyWith(
          color: context.theme.colors.primaryForeground,
        ),
      ),
    );
  }
}
