import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/providers/navigation_provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/// Flutter Hook that centralizes tab reselection logic for scrolling to top.
///
/// This hook encapsulates the common pattern of listening to tab reselection
/// signals and scrolling the associated scroll controller to the top.
///
/// Usage:
/// ```dart
/// class MyScreen extends HookConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final scrollController = useScrollController();
///
///     // Setup tab reselection for tab index 1
///     useTabReselection(
///       ref: ref,
///       controller: scrollController,
///       tabIndex: 1,
///     );
///
///     return ListView(controller: scrollController, ...);
///   }
/// }
/// ```
void useTabReselection({
  required WidgetRef ref,
  required ScrollController controller,
  required int tabIndex,
  bool useAnimation = true,
  Duration animationDuration = const Duration(milliseconds: 300),
  Curve animationCurve = Curves.easeInOut,
}) {
  useEffect(
    () {
      final subscription = ref.listen<TabReselectionSignal>(
        tabReselectionProvider,
        (previous, next) {
          if (next.tabIndex == tabIndex && controller.hasClients) {
            if (useAnimation) {
              controller.animateTo(
                0,
                duration: animationDuration,
                curve: animationCurve,
              );
            } else {
              controller.jumpTo(0);
            }
          }
        },
      );

      return () => subscription.close();
    },
    [controller, tabIndex, useAnimation, animationDuration, animationCurve],
  );
}

/// Flutter Hook for tab reselection with ItemScrollController (for scrollable_positioned_list).
///
/// Used by screens that use scrollable_positioned_list for performance optimization.
///
/// Usage:
/// ```dart
/// class MyScreen extends HookConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final itemScrollController = useMemoized(ItemScrollController.new);
///
///     // Setup tab reselection for tab index 1 with ItemScrollController
///     useTabReselectionWithItemScrollController(
///       ref: ref,
///       controller: itemScrollController,
///       tabIndex: 1,
///     );
///
///     return ScrollablePositionedList.itemScrollController(itemScrollController, ...);
///   }
/// }
/// ```
void useTabReselectionWithItemScrollController({
  required WidgetRef ref,
  required ItemScrollController controller,
  required int tabIndex,
  bool useAnimation = true,
  Duration animationDuration = const Duration(milliseconds: 300),
}) {
  useEffect(
    () {
      final subscription = ref.listen<TabReselectionSignal>(
        tabReselectionProvider,
        (previous, next) {
          if (next.tabIndex == tabIndex && controller.isAttached) {
            if (useAnimation) {
              controller.scrollTo(
                index: 0,
                duration: animationDuration,
              );
            } else {
              controller.jumpTo(index: 0);
            }
          }
        },
      );

      return () => subscription.close();
    },
    [controller, tabIndex, useAnimation, animationDuration],
  );
}
