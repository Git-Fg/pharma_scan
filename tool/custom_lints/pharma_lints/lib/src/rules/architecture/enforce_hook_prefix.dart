import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import '../../utils/lint_utils.dart';

class EnforceHookPrefix extends DartLintRule {
  const EnforceHookPrefix() : super(code: _code);

  static const _code = LintCode(
    name: 'enforce_hook_prefix',
    problemMessage:
        '❌ HOOK RULES: Functions using hooks must start with "use".',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (LintUtils.shouldIgnorePath(resolver.path)) return;

    context.registry.addCompilationUnit((node) {
      final visitor = _HookUsageVisitor(reporter);
      node.accept(visitor);
    });
  }
}

class _HookUsageVisitor extends RecursiveAstVisitor<void> {
  final ErrorReporter _reporter;
  final List<String> _functionStack = [];

  _HookUsageVisitor(this._reporter);

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _functionStack.add(node.name.lexeme);
    super.visitFunctionDeclaration(node);
    _functionStack.removeLast();
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _functionStack.add(node.name.lexeme);
    super.visitMethodDeclaration(node);
    _functionStack.removeLast();
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;

    // Optimized hook detection: startswith 'use' AND second char is Uppercase (CamelCase)
    // Regex eq: ^use[A-Z]
    if (name.startsWith('use') &&
        name.length > 3 &&
        _isUpperCase(name.codeUnitAt(3))) {
      _checkHookUsage(node, name);
    }

    super.visitMethodInvocation(node);
  }

  bool _isUpperCase(int charCode) {
    return charCode >= 65 && charCode <= 90;
  }

  void _checkHookUsage(MethodInvocation node, String hookName) {
    if (_functionStack.isEmpty) return;

    final currentFunction = _functionStack.last;

    // Allowed contexts:
    // 1. Function starts with 'use' (custom hook)
    // 2. Function is 'build' (widget build method)
    if (currentFunction.startsWith('use')) return;
    if (currentFunction == 'build') return;

    _reporter.atOffset(
      offset: node.offset,
      length: node.length,
      errorCode: EnforceHookPrefix._code,
    );
  }
}
