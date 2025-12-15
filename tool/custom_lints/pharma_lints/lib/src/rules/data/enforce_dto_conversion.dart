import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import '../../utils/lint_utils.dart';

class EnforceDtoConversion extends DartLintRule {
  const EnforceDtoConversion() : super(code: _code);

  static const _code = LintCode(
    name: 'enforce_dto_conversion',
    problemMessage: '❌ DATA MODEL: Model classes must implement `toEntity()`.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (LintUtils.shouldIgnorePath(resolver.path)) return;

    context.registry.addClassDeclaration((node) {
      final className = node.name.lexeme;
      if (!className.endsWith('Model')) return;

      bool hasToEntity = false;
      for (final member in node.members) {
        if (member is MethodDeclaration) {
          if (member.name.lexeme == 'toEntity') {
            hasToEntity = true;
            break;
          }
        }
      }

      if (!hasToEntity) {
        reporter.atOffset(
          offset: node.offset,
          length: node.length,
          errorCode: _code,
        );
      }
    });
  }
}
