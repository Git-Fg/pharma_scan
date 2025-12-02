import 'package:flutter/material.dart';
import 'package:pharma_scan/core/utils/test_tags.dart' show TestTags;

/// Wrapper widget that adds test identifiers via Semantics.
///
/// This widget provides ID-based matching for Integration Tests, ensuring stable
/// selectors that don't break when UI text changes.
///
/// Usage:
/// ```dart
/// Testable(
///   id: TestTags.navScanner,
///   child: ShadButton(...),
/// )
/// ```
///
/// When `merge` is true (default), the widget uses `MergeSemantics` to
/// merge the identifier with existing semantics from the child. This is
/// useful when the child already has semantic properties (like labels)
/// that should be preserved.
///
/// When `merge` is false, the identifier is set directly on a `Semantics`
/// widget, which may override existing semantics.
class Testable extends StatelessWidget {
  Testable({required this.id, required this.child, this.merge = true, Key? key})
    : super(key: key ?? ValueKey(id));

  /// The test identifier to use for E2E matching.
  ///
  /// Should be a constant from [TestTags].
  final String id;

  /// The widget to wrap with test semantics.
  final Widget child;

  /// Whether to merge semantics with the child.
  ///
  /// When true (default), uses `MergeSemantics` to preserve existing
  /// semantic properties from the child while adding the identifier.
  /// When false, wraps the child in `Semantics` which may override
  /// existing semantics.
  final bool merge;

  @override
  Widget build(BuildContext context) {
    if (merge) {
      return MergeSemantics(
        child: Semantics(identifier: id, child: child),
      );
    } else {
      return Semantics(identifier: id, child: child);
    }
  }
}
