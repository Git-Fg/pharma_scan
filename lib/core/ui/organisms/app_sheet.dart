import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    List<Widget>? actions,
  }) {
    return showShadSheet<T>(
      context: context,
      side: _getSheetSide(context),
      builder: (context) => ShadSheet(
        title: Text(title),
        actions: actions ?? const [],
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16), // spacingMd
          child: child,
        ),
      ),
    );
  }

  static ShadSheetSide _getSheetSide(BuildContext context) {
    // Default to mobile behavior for now
    return ShadSheetSide.bottom;
  }
}

/// Widget wrapper that renders a styled ShadSheet. Use this in features
/// when the sheet is constructed by the feature and presented by a central
/// sheet opener (e.g., `AppSheet.show`). This keeps imports of Shadcn
/// inside `lib/core/ui` only.
class AppSheetWidget extends StatelessWidget {
  const AppSheetWidget({
    super.key,
    required this.title,
    this.description,
    required this.child,
    this.actions,
  });

  final Widget title;
  final Widget? description;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return ShadSheet(
      title: title,
      description: description,
      actions: actions ?? const [],
      child: child,
    );
  }
}
