import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';

void main() {
  group('extractPrincepsLabel', () {
    test('returns last segment for simple group label', () {
      expect(
        extractPrincepsLabel('ALLOPURINOL 100 mg - ZYLORIC'),
        equals('ZYLORIC'),
      );
    });

    test('uses last hyphen segment for multi-brand group labels', () {
      const label =
          'DOMPERIDONE 10 mg - MOTILIUM 10 mg, comprimé pelliculé - PERIDYS 10 mg, comprimé pelliculé.';

      expect(
        extractPrincepsLabel(label),
        equals('PERIDYS 10 mg, comprimé pelliculé.'),
      );
    });

    test('returns trimmed label when no hyphen and no comma', () {
      expect(
        extractPrincepsLabel('  GLUCOPHAGE 500 mg  '),
        equals('GLUCOPHAGE 500 mg'),
      );
    });

    test('does not split on comma when there is no hyphen', () {
      expect(
        extractPrincepsLabel('DOLIPRANE 1000 mg, comprimé'),
        equals('DOLIPRANE 1000 mg, comprimé'),
      );
    });

    test('handles odd spacing around hyphen separator', () {
      const label =
          'OMEPRAZOLE 20 mg   -   MOPRAL 20 mg, gélule gastro-résistante';

      expect(
        extractPrincepsLabel(label),
        equals('MOPRAL 20 mg, gélule gastro-résistante'),
      );
    });

    test('preserves trailing punctuation in last segment', () {
      const label =
          'PHLOROGLUCINOL (HYDRATE) 80 mg - SPASFON LYOC 80 mg, lyophilisat oral.';

      final result = extractPrincepsLabel(label);
      expect(result, equals('SPASFON LYOC 80 mg, lyophilisat oral.'));
      expect(result.endsWith('.'), isTrue);
    });
  });

  // NOTE: sanitizeActivePrinciple tests removed - function is deprecated.
  // normalizePrincipleOptimal has comprehensive tests in normalize_principle_optimal_test.dart
  // These two functions have different purposes:
  // - sanitizeActivePrinciple: Removed dosages/formulations for display
  // - normalizePrincipleOptimal: Normalizes for grouping (removes salts, forms, normalizes spelling)
}
