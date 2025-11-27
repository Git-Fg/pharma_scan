// lib/core/widgets/ui_kit/badges/princeps_badge.dart
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:pharma_scan/core/utils/strings.dart';

/// Badge widget for displaying "PRINCEPS" label.
/// Uses secondary color scheme to distinguish from generic medications.
class PrincepsBadge extends StatelessWidget {
  const PrincepsBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return FBadge(
      style: FBadgeStyle.secondary(),
      child: Text(Strings.badgePrinceps, style: context.theme.typography.sm),
    );
  }
}
