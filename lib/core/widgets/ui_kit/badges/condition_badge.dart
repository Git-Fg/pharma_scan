// lib/core/widgets/ui_kit/badges/condition_badge.dart
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Badge widget for displaying prescription condition text.
/// Returns null if conditionText is null or empty.
/// Uses outline style to distinguish from status badges.
class ConditionBadge extends StatelessWidget {
  const ConditionBadge({super.key, required this.conditionText});

  final String? conditionText;

  /// Factory constructor that returns null if conditionText is empty.
  /// This allows for conditional rendering in widget trees.
  static Widget? condition(BuildContext context, String? conditionText) {
    if (conditionText == null || conditionText.isEmpty) return null;
    return ConditionBadge(conditionText: conditionText);
  }

  @override
  Widget build(BuildContext context) {
    return FBadge(
      style: FBadgeStyle.outline(),
      child: Text(conditionText!, style: context.theme.typography.sm),
    );
  }
}
