// lib/core/widgets/accessible_touch.dart
import 'package:flutter/material.dart';

/// Reusable widget that combines Semantics and touch handling for accessibility.
/// Simplifies the widget tree by replacing nested Semantics/InkWell/Material patterns.
class AccessibleTouch extends StatelessWidget {
  const AccessibleTouch({
    required this.label,
    this.onTap,
    required this.child,
    this.borderRadius,
    this.splashColor,
    this.highlightColor,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius? borderRadius;
  final Color? splashColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) {
      return Semantics(label: label, child: child);
    }

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: splashColor,
          highlightColor: highlightColor,
          child: child,
        ),
      ),
    );
  }
}
