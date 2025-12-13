import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

extension SemanticColors on ShadColorScheme {
  // Form type colors mapped to semantic shadcn_ui tokens
  // Using semantic tokens ensures consistency and proper dark/light mode support
  Color get formSolid => primary; // Use primary green for solid forms
  Color get formLiquid => secondary; // Use secondary for liquids
  Color get formSemiSolid => muted; // Use muted for semi-solids (as tertiary doesn't exist)
  Color get formInjectable => destructive; // Use destructive for injectables (high attention)
}
