import 'package:flutter/material.dart';
import 'package:pharma_scan/core/domain/types/pharmaceutical_form.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Color getFormColor(ShadColorScheme colors, String? form) {
  final formType = PharmaFormType.fromLabel(form);
  return formType.resolveColor(colors);
}

String formatForClipboard({
  required int quantity,
  required String label,
  required String cip,
}) {
  return '$quantity x $label (CIP: $cip)';
}
