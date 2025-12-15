import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import '../../utils/lint_utils.dart';

class AvoidManualTypography extends DartLintRule {
  const AvoidManualTypography() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_manual_typography',
    problemMessage:
        '❌ DESIGN SYSTEM: Avoid manual TextStyle instantiation. Use ShadTheme typography tokens (context.typo.h1, context.typo.body, etc.).',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (LintUtils.shouldIgnorePath(resolver.path)) return;

    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.toSource();
      if (typeName == 'TextStyle') {
        // Allow TextStyle inside ShadTheme config or where explicitly needed (heuristic)
        // For now, flag all usages in feature/core code to encourage refactoring.
        // We might want to skip if it's inside a 'style:' parameter of a Text widget IF it's likely a theme override,
        // but generally we want 'context.typo.something.copyWith()' rather than 'TextStyle(...)'.

        reporter.atOffset(
          offset: node.offset,
          length: node.length,
          errorCode: _code,
        );
      }
    });
  }
}
