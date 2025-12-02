import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// Detects horizontal swipe gestures and triggers back navigation.
/// Specifically detects right-to-left swipe (swipe right) to go back.
class SwipeBackDetector extends StatefulWidget {
  const SwipeBackDetector({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<SwipeBackDetector> createState() => _SwipeBackDetectorState();
}

class _SwipeBackDetectorState extends State<SwipeBackDetector> {
  double _dragDelta = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        // Track horizontal drag for potential back gesture
        _dragDelta = details.primaryDelta ?? 0;
      },
      onHorizontalDragEnd: (details) {
        // If swiped right (positive delta) with sufficient velocity/distance
        if (_dragDelta > 20 || (details.primaryVelocity ?? 0) > 300) {
          unawaited(context.router.maybePop());
        }
        _dragDelta = 0;
      },
      child: widget.child,
    );
  }
}
