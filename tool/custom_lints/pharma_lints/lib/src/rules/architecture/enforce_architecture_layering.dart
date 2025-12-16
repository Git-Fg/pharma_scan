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

    final currentScope = LintUtils.parse(resolver.path);
    
    // Only enforce rules if we are in a known layer
    if (currentScope.layer == ArchitectureLayer.unknown) return;
    if (currentScope.isTest) return;

    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;

      // Parse the imported URI to check its layer
      // We can't use LintUtils.parse(uri) directly because uri is relative or package:
      // We need to resolve it or do string analysis on the URI.
      
      // 1. Check direct package imports
      if (uri.startsWith('package:pharma_scan/')) {
        _checkPackageImport(uri, currentScope, reporter, node);
      } 
      // 2. Check relative imports
      else if (!uri.startsWith('dart:') && !uri.startsWith('package:')) {
         // Resolve relative path to absolute or project-relative
         // This is tricky without resolving, but we can check if it goes "up" into another layer
         // simpler heuristic: check for '/features/' or '/core/' in the path if it traverses up
         if (uri.contains('/features/') || uri.contains('/core/')) {
            _checkRelativeImport(uri, currentScope, reporter, node);
         }
      }
    });
  }

  void _checkPackageImport(
    String importUri,
    ArchitectureScope currentScope,
    ErrorReporter reporter,
    ImportDirective node,
  ) {
    if (importUri.startsWith('package:pharma_scan/features/')) {
       final featureParts = importUri.split('/');
       if (featureParts.length > 2) {
          final importedFeature = featureParts[2];
          
          if (currentScope.layer == ArchitectureLayer.core) {
            reporter.atOffset(
              offset: node.offset,
              length: node.length,
              errorCode: LintCode(
                  name: 'enforce_architecture_layering',
                  problemMessage:
                      '❌ CORE VIOLATION: Core cannot depend on Features ($importedFeature).'),
            );
          } else if (currentScope.layer == ArchitectureLayer.features) {
             if (currentScope.featureName != null && importedFeature != currentScope.featureName) {
                reporter.atOffset(
                  offset: node.offset,
                  length: node.length,
                  errorCode: LintCode(
                      name: 'enforce_architecture_layering',
                      problemMessage:
                          '❌ FEATURE VIOLATION: Feature (${currentScope.featureName}) cannot import unrelated Feature ($importedFeature).'),
                );
             }
          }
       }
    }
  }

  void _checkRelativeImport(
    String importUri,
    ArchitectureScope currentScope,
    ErrorReporter reporter,
    ImportDirective node,
  ) {
    // Basic heuristic for relative imports crossing layers
    // mostly concerned if we are in core and importing ../features/
    if (currentScope.layer == ArchitectureLayer.core) {
       if (importUri.contains('features/')) {
          reporter.atOffset(
            offset: node.offset,
            length: node.length,
            errorCode: LintCode(
                name: 'enforce_architecture_layering',
                problemMessage:
                    '❌ CORE VIOLATION: Core cannot depend on Features (via relative import).'),
          );
       }
    }
  }
}
