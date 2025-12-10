import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

extension SemanticColors on ShadColorScheme {
  Color get formSolid => Colors.blue.shade600;
  Color get formLiquid => Colors.orange.shade600;
  Color get formSemiSolid => Colors.purple.shade600;
  Color get formInjectable => Colors.red.shade600;
}
