// lib/core/widgets/ui_kit/badges/standalone_badge.dart
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:pharma_scan/core/utils/strings.dart';

/// Badge widget for displaying "UNIQUE" label.
/// Used for medications that do not belong to any generic group.
/// Uses muted color scheme to indicate standalone status.
class StandaloneBadge extends StatelessWidget {
  const StandaloneBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return FBadge(
      style: FBadgeStyle.primary(),
      child: Text(Strings.badgeStandalone, style: context.theme.typography.sm),
    );
  }
}
