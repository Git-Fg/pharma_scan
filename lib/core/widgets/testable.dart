import 'package:flutter/material.dart';
import 'package:pharma_scan/core/utils/test_tags.dart' show TestTags;

/// Adds a stable test identifier to a child via Semantics.
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
