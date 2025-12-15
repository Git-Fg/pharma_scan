import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

/// Utilities for optimizing lint rules
class LintUtils {
  /// Check if a path should be ignored (generated files, tests)
  static bool shouldIgnorePath(String path) {
    return path.contains('.g.dart') ||
        path.contains('.freezed.dart') ||
        path.contains('.drift.dart') ||
        path.contains('.mapper.dart') ||
        path.contains('test/');
  }

  /// Fast syntax-only check if a node could be a Color constructor
  static bool couldBeColorInstantiation(InstanceCreationExpression node) {
    // Check purely syntactic name before doing expensive type resolution
    final name = node.constructorName.type.name2.lexeme;
    return name == 'Color';
  }

  /// Fast syntax-only check if a node could be Colors.something
  static bool couldBeColorsAccess(PrefixedIdentifier node) {
    return node.prefix.name == 'Colors';
  }
}
