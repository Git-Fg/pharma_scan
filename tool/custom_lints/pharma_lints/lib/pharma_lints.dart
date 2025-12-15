library pharma_lints;

import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'src/rules/design_system/avoid_direct_colors.dart';
import 'src/rules/design_system/avoid_print.dart';
import 'src/rules/architecture/enforce_architecture_layering.dart';
import 'src/rules/architecture/enforce_ui_isolation.dart';
import 'src/rules/architecture/enforce_hook_prefix.dart';
import 'src/rules/data/enforce_dto_conversion.dart';

PluginBase createPlugin() => _PharmaScanLints();

class _PharmaScanLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const AvoidDirectColors(),
        const AvoidPrint(),
        const EnforceArchitectureLayering(),
        const EnforceUiIsolation(),
        const EnforceHookPrefix(),
        const EnforceDtoConversion(),
      ];
}
