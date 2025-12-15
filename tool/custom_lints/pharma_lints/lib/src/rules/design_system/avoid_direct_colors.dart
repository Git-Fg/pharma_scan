import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' hide LintCode;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import '../../utils/lint_utils.dart';

class AvoidDirectColors extends DartLintRule {
  const AvoidDirectColors() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_direct_colors',
    problemMessage: '❌ FORBIDDEN: Direct color usage breaks the design system.',
    correctionMessage:
        'Use context.shadColors.<semanticColor> or context.shadTheme.colorScheme.<color>.',
  );

  static const _infoCode = LintCode(
    name: 'avoid_direct_colors',
    problemMessage: 'ℹ️ INFO: Consider using theme colors for consistency.',
    correctionMessage:
        'Use context.shadColors.<semanticColor> or add // ignore: avoid_direct_colors',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (LintUtils.shouldIgnorePath(resolver.path)) return;
    final isMainFile = resolver.path.endsWith('lib/main.dart');
    final isThemeFile =
        resolver.path.endsWith('lib/core/ui/theme/app_theme.dart');
    if (isThemeFile) return;

    // Registry for Color(...) constructor checks
    context.registry.addInstanceCreationExpression((node) {
      if (!LintUtils.couldBeColorInstantiation(node)) return;

      final typeName =
          node.staticType?.getDisplayString(withNullability: false);
      if (typeName == 'Color' && node.argumentList.arguments.isNotEmpty) {
        reporter.atOffset(
          offset: node.offset,
          length: node.length,
          errorCode: isMainFile ? _infoCode : _code,
        );
      }
    });

    // Registry for Colors.red, Colors.blue access checks
    context.registry.addPrefixedIdentifier((node) {
      if (!LintUtils.couldBeColorsAccess(node)) return;

      final identifier = node.identifier.name;
      // Allow transparent, black, white (often used as base values)
      if (identifier == 'transparent' ||
          identifier == 'black' ||
          identifier == 'white') {
        return;
      }

      reporter.atOffset(
        offset: node.offset,
        length: node.length,
        errorCode: isMainFile ? _infoCode : _code,
      );
    });
  }

  @override
  List<Fix> getFixes() => [_IgnoreWarningFix()];
}

class _IgnoreWarningFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Ignore this warning',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// ignore: avoid_direct_colors\n',
        );
      });
    });

    context.registry.addPrefixedIdentifier((node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final changeBuilder = reporter.createChangeBuilder(
        message: 'Ignore this warning',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// ignore: avoid_direct_colors\n',
        );
      });
    });
  }
}
