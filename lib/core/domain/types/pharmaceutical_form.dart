import 'package:flutter/material.dart';
import 'package:pharma_scan/core/theme/semantic_colors.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum PharmaFormType {
  solid(['comprim', 'gelule', 'gélule', 'capsule']),
  liquid(['sirop', 'solution', 'buvable']),
  semiSolid(['creme', 'crème', 'pommade', 'gel']),
  injectable(['inject', 'perf']),
  other([])
  ;

  const PharmaFormType(this.keywords);

  final List<String> keywords;

  static PharmaFormType fromLabel(String? raw) {
    if (raw == null || raw.isEmpty) return PharmaFormType.other;
    final normalized = raw.toLowerCase();
    return PharmaFormType.values.firstWhere(
      (type) => type.keywords.any(normalized.contains),
      orElse: () => PharmaFormType.other,
    );
  }

  Color resolveColor(ShadColorScheme colors) => switch (this) {
    PharmaFormType.solid => colors.formSolid,
    PharmaFormType.liquid => colors.formLiquid,
    PharmaFormType.semiSolid => colors.formSemiSolid,
    PharmaFormType.injectable => colors.formInjectable,
    PharmaFormType.other => colors.mutedForeground,
  };
}
