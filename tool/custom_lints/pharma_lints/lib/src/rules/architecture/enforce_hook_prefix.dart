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

    // Logic:
    // 1. Visit FunctionDeclaration or MethodDeclaration
    // 2. Scan body for MethodInvocation starting with 'use' (excluding known non-hooks if any)
    // 3. If found, check if parent function starts with 'use' or is 'build'.

    // We will simplify: If a function calls a hook, it must be named 'use...' or be a 'build' method.

    context.registry.addFunctionDeclaration((node) {
      _checkBody(
          node.name.lexeme, node.functionExpression.body, reporter, node);
    });

    context.registry.addMethodDeclaration((node) {
      _checkBody(node.name.lexeme, node.body, reporter, node);
    });
  }

  void _checkBody(String functionName, FunctionBody body,
      ErrorReporter reporter, AstNode node) {
    // If function already starts with 'use', acceptable.
    if (functionName.startsWith('use')) return;
    // If function is 'build', acceptable (typical widget build).
    if (functionName == 'build') return;

    bool usesHooks = false;

    // We need to traverse the body to find hooks.
    // Creating a visitor just for this body.
    final visitor = _HookUsageVisitor();
    body.visitChildren(visitor);
    usesHooks = visitor.usesHooks;

    if (usesHooks) {
      reporter.atOffset(
        offset: node.offset,
        length: node.length,
        errorCode: _code,
      );
    }
  }
}

class _HookUsageVisitor extends RecursiveAstVisitor<void> {
  bool usesHooks = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (usesHooks) return; // Already found one
    final name = node.methodName.name;
    if (name.startsWith('use') && name != 'use' && name.length > 3) {
      // Very basic heuristic for hook detection (useEffect, useState, etc.)
      // Exclude simple words? No, standard is strict prefix.
      usesHooks = true;
    }
    super.visitMethodInvocation(node);
  }
}
