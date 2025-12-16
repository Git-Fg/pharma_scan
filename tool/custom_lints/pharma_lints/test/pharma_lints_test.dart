import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:test/test.dart';
import 'package:pharma_lints/src/rules/design_system/avoid_direct_colors.dart';
import 'package:pharma_lints/src/rules/architecture/enforce_architecture_layering.dart';
import 'package:pharma_lints/src/rules/architecture/enforce_ui_isolation.dart';
import 'package:pharma_lints/src/rules/architecture/enforce_hook_prefix.dart';
import 'package:pharma_lints/src/rules/data/enforce_dto_conversion.dart';
import 'dart:io';

void main() {
  test('Pharma Lints Verification', () async {
    final file = File('test/src/lint_validation.dart');
    if (!file.existsSync()) {
      fail('Validation file not found: ${file.path}');
    }

    // Resolving all rules
    final rules = [
      const AvoidDirectColors(),
      const EnforceArchitectureLayering(),
      const EnforceUiIsolation(),
      const EnforceHookPrefix(),
      const EnforceDtoConversion(),
    ];
  });
}
