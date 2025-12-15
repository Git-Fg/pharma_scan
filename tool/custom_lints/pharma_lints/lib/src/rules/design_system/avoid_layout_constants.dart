import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';
import '../../utils/lint_utils.dart';

class AvoidLayoutConstants extends DartLintRule {
  const AvoidLayoutConstants() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_layout_constants',
    problemMessage:
        '❌ DESIGN SYSTEM: Avoid dedicated layout constant classes (AppDimens, AppSpacing). Use ShadTheme context tokens (context.spacing.*, context.radius) or local constants for single-use values.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    if (LintUtils.shouldIgnorePath(resolver.path)) return;

    context.registry.addClassDeclaration((node) {
      final name = node.name.lexeme;

      // Target specific legacy class names
      if (name == 'AppDimens' ||
          name == 'AppSpacing' ||
          name == 'Dimens' ||
          name == 'Spacing') {
        reporter.atOffset(
          offset: node.name.offset,
          length: node.name.length,
          errorCode: _code,
        );
        return;
      }

      // Heuristic: Check if class is a "pure constants wrapper"
      // 1. All fields are static const
      // 2. All fields are double
      // 3. Class has private constructor (utils class pattern)
      // 4. Has "Dimens" or "Spacing" or "Sizes" in name
      if (name.contains('Dimens') ||
          name.contains('Spacing') ||
          name.contains('Sizes')) {
        bool allStaticConstDoubles = true;
        bool hasFields = false;

        for (final member in node.members) {
          if (member is FieldDeclaration) {
            hasFields = true;
            if (!member.isStatic) {
              allStaticConstDoubles = false;
              break;
            }
            // Check type
            final type = member.fields.type;
            if (type?.toSource() != 'double') {
              // Allow some exceptions? For now be strict on "Dimens" classes.
              // If it's not explicitly 'double', maybe it's inferred. Checking strict for now.
              if (type != null) {
                // if type is omitted it might be dynamic/var/double, assume unsafe unless explicitly double
                allStaticConstDoubles = false;
                break;
              }
            }
          } else if (member is ConstructorDeclaration) {
            // Ignore constructors
          } else {
            // Methods?
            allStaticConstDoubles = false;
            break;
          }
        }

        if (hasFields && allStaticConstDoubles) {
          reporter.atOffset(
            offset: node.name.offset,
            length: node.name.length,
            errorCode: _code,
          );
        }
      }
    });
  }
}
