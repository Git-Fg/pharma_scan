// lib/core/utils/adaptive_overlay.dart
import 'package:flutter/cupertino.dart' show MediaQuery;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' show MediaQuery;
import 'package:shadcn_ui/shadcn_ui.dart';

/// A lightweight responsive dispatcher that opens a Sheet on mobile and a Dialog on desktop.
///
/// **Crucial:** This function does NOT handle scrolling or keyboard padding.
/// The [builder] widget is responsible for its own layout, scrolling (e.g. via [SingleChildScrollView]),
/// and keyboard avoidance (e.g. via [Padding] with [MediaQuery.viewInsets]).
///
/// [constraints] can be used to set explicit size constraints for the sheet.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  BoxConstraints? constraints,
}) {
  // WHY: Use context.breakpoint extension for consistent responsive pattern
  // This aligns with the Shadcn 2025 Standard for responsive design
  final breakpoint = context.breakpoint;
  final breakpoints = ShadTheme.of(context).breakpoints;
  final isSmallScreen = breakpoint < breakpoints.sm;

  if (isSmallScreen) {
    // WHY: Mobile uses bottom sheet for better UX
    return showShadSheet<T>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (BuildContext sheetContext) {
        // Apply constraints if provided, otherwise let sheet size naturally
        final content = builder(sheetContext);
        if (constraints != null) {
          return ConstrainedBox(constraints: constraints, child: content);
        }
        return content;
      },
    );
  } else {
    // WHY: Desktop uses dialog for better UX
    return showShadDialog<T>(
      context: context,
      builder: (BuildContext dialogContext) {
        return ShadDialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: builder(dialogContext),
          ),
        );
      },
    );
  }
}
