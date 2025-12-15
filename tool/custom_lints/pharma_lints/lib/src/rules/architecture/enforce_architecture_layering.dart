import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import '../../utils/lint_utils.dart';

class EnforceArchitectureLayering extends DartLintRule {
  const EnforceArchitectureLayering() : super(code: _code);

  static const _code = LintCode(
    name: 'enforce_architecture_layering',
    problemMessage: '❌ ARCHITECTURE: Invalid layer dependency.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (LintUtils.shouldIgnorePath(resolver.path)) return;

    // Normalize path for Windows support
    final path = resolver.path.replaceAll('\\', '/');

    // Normalized path parts
    final parts = path.split('/');
    final libIndex = parts.indexOf('lib');
    if (libIndex == -1 || libIndex + 2 >= parts.length) return;

    final layer = parts[libIndex + 1]; // features, core, etc.
    if (layer != 'features' && layer != 'core') return;

    final currentFeature = (layer == 'features') ? parts[libIndex + 2] : null;

    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;

      // 1. Check direct package imports
      if (uri.startsWith('package:pharma_scan/features/')) {
        _checkFeatureImport(uri, layer, currentFeature, reporter, node);
      } else if (uri.startsWith('package:pharma_scan/core/') &&
          layer == 'core') {
        // Core inside Core is fine generally, but maybe check for cycles?
      }

      // 2. Check relative imports (approximated)
      // Only check if it's NOT a package import we already checked
      else if (!uri.startsWith('package:pharma_scan/features/') &&
          uri.contains('/features/')) {
        // If we are in core, we shouldn't import features
        if (layer == 'core')
          reporter.atOffset(
            offset: node.offset,
            length: node.length,
            errorCode: LintCode(
                name: 'enforce_architecture_layering',
                problemMessage:
                    '❌ CORE VIOLATION: Core cannot depend on Features ($uri).'),
          );
      }
    });
  }

  void _checkFeatureImport(
    String importUri,
    String currentLayer,
    String? currentFeature,
    ErrorReporter reporter,
    ImportDirective node,
  ) {
    // Extract imported feature
    // package:pharma_scan/features/scanner/...
    final segments = importUri.split('/');
    final featureIndex = segments.indexOf('features');
    if (featureIndex == -1 || featureIndex + 1 >= segments.length) return;

    final importedFeature = segments[featureIndex + 1];

    if (currentLayer == 'core') {
      reporter.atOffset(
        offset: node.offset,
        length: node.length,
        errorCode: LintCode(
            name: 'enforce_architecture_layering',
            problemMessage:
                '❌ CORE VIOLATION: Core cannot depend on Features ($importedFeature).'),
      );
    } else if (currentLayer == 'features' && currentFeature != null) {
      if (importedFeature != currentFeature) {
        reporter.atOffset(
          offset: node.offset,
          length: node.length,
          errorCode: LintCode(
              name: 'enforce_architecture_layering',
              problemMessage:
                  '❌ FEATURE VIOLATION: Feature ($currentFeature) cannot import unrelated Feature ($importedFeature).'),
        );
      }
    }
  }
}
