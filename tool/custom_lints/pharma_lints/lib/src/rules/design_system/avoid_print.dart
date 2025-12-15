import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import '../../utils/lint_utils.dart';

class AvoidPrint extends DartLintRule {
  const AvoidPrint() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_print',
    problemMessage:
        '❌ OBSERVABILITY: Do not use print/debugPrint in production.',
    correctionMessage: 'Use ref.read(loggerProvider).info() or .error().',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (LintUtils.shouldIgnorePath(resolver.path)) return;

    context.registry.addMethodInvocation((node) {
      final name = node.methodName.name;
      if (name == 'print' || name == 'debugPrint') {
        // Ensure it's the global function, not a method on an object
        if (node.target == null) {
          reporter.atOffset(
            offset: node.offset,
            length: node.length,
            errorCode: _code,
          );
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => [_UseLoggerFix()];
}

class _UseLoggerFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Replace with Logger (Placeholder)',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Replacing 'print(x)' with 'logger.info(x)' is tricky because we need the 'logger' instance related to Riverpod.
        // For now, we'll just rename it to warn the user or add a TODO, as fully resolving the provider is hard in a quick fix.
        // BUT the user asked for "Correction: ref.read(loggerProvider)..."
        // Let's try to be helpful.
        builder.addSimpleReplacement(
          node.methodName.sourceRange,
          'ref.read(loggerProvider).info',
        );
      });
    });
  }
}
