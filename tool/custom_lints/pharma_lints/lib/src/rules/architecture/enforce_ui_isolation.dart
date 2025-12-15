import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import '../../utils/lint_utils.dart';

class EnforceUiIsolation extends DartLintRule {
  const EnforceUiIsolation() : super(code: _code);

  static const _code = LintCode(
    name: 'enforce_ui_isolation',
    problemMessage:
        '❌ THIN CLIENT: UI layer cannot import Drift/Database directly.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (LintUtils.shouldIgnorePath(resolver.path)) return;

    // Only apply to UI layer
    // Usually defined as inside 'presentation' or 'view' folders or widgets
    // We'll use a simple heuristic: file path contains 'presentation/' or 'screens/' or 'widgets/'
    final path = resolver.path.replaceAll('\\', '/');
    if (!path.contains('/presentation/') &&
        !path.contains('/screens/') &&
        !path.contains('/widgets/')) {
      return;
    }

    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;

      final isDrift =
          uri.contains('package:drift/') || uri.contains('.drift.dart');

      if (isDrift) {
        reporter.atOffset(
          offset: node.offset,
          length: node.length,
          errorCode: _code,
        );
      }
    });
  }
}
