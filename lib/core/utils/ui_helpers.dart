import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Color getFormColor(ShadColorScheme colors, String? form) {
  if (form == null) return colors.muted;
  final f = form.toLowerCase();

  if (f.contains('comprim') || f.contains('gélule') || f.contains('capsule')) {
    return Colors.blue.shade600; // Solides
  }
  if (f.contains('sirop') || f.contains('solution') || f.contains('buvable')) {
    return Colors.orange.shade600; // Liquides
  }
  if (f.contains('crème') || f.contains('pommade') || f.contains('gel')) {
    return Colors.purple.shade600; // Semi-solides
  }
  if (f.contains('inject') || f.contains('perf')) {
    return Colors.red.shade600; // Injectables
  }
  return colors.mutedForeground; // Autre
}

String formatForClipboard({
  required int quantity,
  required String label,
  required String cip,
}) {
  return '$quantity x $label (CIP: $cip)';
}
