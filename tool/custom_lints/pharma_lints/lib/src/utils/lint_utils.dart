import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;

enum ArchitectureLayer {
  core,
  features,
  domain,
  ui,
  unknown,
}

class ArchitectureScope {
  final ArchitectureLayer layer;
  final String? featureName;
  final bool isTest;

  const ArchitectureScope({
    required this.layer,
    this.featureName,
    this.isTest = false,
  });

  @override
  String toString() =>
      'ArchitectureScope(layer: $layer, feature: $featureName, isTest: $isTest)';
}

/// Utilities for optimizing lint rules
class LintUtils {
  /// Check if a path should be ignored (generated files, tests)
  static bool shouldIgnorePath(String path) {
    return path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart') ||
        path.endsWith('.drift.dart') ||
        path.endsWith('.mapper.dart') ||
        // Keep test/ check for safety, but usually we ignore test folders in analysis_options
        path.contains('/test/');
  }

  /// Parses the architectural scope of a given file path.
  static ArchitectureScope parse(String path) {
    // Normalize path separators
    final normalizedPath = p.posix.joinAll(p.split(path));

    // Check if it's a test file
    final isTest = normalizedPath.contains('/test/') ||
        normalizedPath.endsWith('_test.dart');

    final parts = normalizedPath.split('/');
    final libIndex = parts.indexOf('lib');

    if (libIndex == -1 || libIndex + 1 >= parts.length) {
      return ArchitectureScope(
        layer: ArchitectureLayer.unknown,
        isTest: isTest,
      );
    }

    final topLevelDir = parts[libIndex + 1];

    if (topLevelDir == 'core') {
      return ArchitectureScope(
        layer: ArchitectureLayer.core,
        isTest: isTest,
      );
    } else if (topLevelDir == 'features') {
      // Expecting lib/features/<feature_name>/...
      if (libIndex + 2 < parts.length) {
        return ArchitectureScope(
          layer: ArchitectureLayer.features,
          featureName: parts[libIndex + 2],
          isTest: isTest,
        );
      }
    }

    // Add other layers if defined in the future (domain, ui, etc.)

    return ArchitectureScope(
      layer: ArchitectureLayer.unknown,
      isTest: isTest,
    );
  }

  /// Fast syntax-only check if a node could be a Color constructor
  /// Fast syntax-only check if a node could be a Color constructor
  static bool couldBeColorInstantiation(InstanceCreationExpression node) {
    // Check purely syntactic name before doing expensive type resolution
    // Fix deprecation: name2 -> name
    final name = node.constructorName.type.name.lexeme;
    return name == 'Color';
  }

  /// Fast syntax-only check if a node could be Colors.something
  static bool couldBeColorsAccess(PrefixedIdentifier node) {
    return node.prefix.name == 'Colors';
  }
}
