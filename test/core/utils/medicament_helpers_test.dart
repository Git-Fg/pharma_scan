import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';

void main() {
  group('sanitizeActivePrinciple', () {
    test('should remove formulation keywords like comprimé', () {
      expect(
        sanitizeActivePrinciple('IBUPROFENE 200 mg comprimé'),
        equals('IBUPROFENE'),
      );
      expect(
        sanitizeActivePrinciple('PARACETAMOL comprimé'),
        equals('PARACETAMOL'),
      );
    });

    test('should remove dosage units and numbers', () {
      expect(
        sanitizeActivePrinciple('ESOMEPRAZOLE MAGNESIUM TRIHYDRATE équivalant à ESOMEPRAZOLE 40 mg'),
        equals('ESOMEPRAZOLE MAGNESIUM TRIHYDRATE'),
      );
      expect(
        sanitizeActivePrinciple('PARACETAMOL 500 mg'),
        equals('PARACETAMOL'),
      );
    });

    test('should preserve legitimate molecule names with numbers', () {
      expect(
        sanitizeActivePrinciple('HEPARINE SODIQUE 4000 UI/ML'),
        contains('4000'),
      );
      expect(
        sanitizeActivePrinciple('HEPARINE 3350 UI/ML'),
        contains('3350'),
      );
    });

    test('should handle parenthetical content', () {
      expect(
        sanitizeActivePrinciple('MOLECULE (sel de sodium)'),
        equals('MOLECULE'),
      );
    });

    test('should handle "équivalant à" patterns', () {
      expect(
        sanitizeActivePrinciple('ESOMEPRAZOLE MAGNESIUM TRIHYDRATE équivalant à ESOMEPRAZOLE 40 mg'),
        equals('ESOMEPRAZOLE MAGNESIUM TRIHYDRATE'),
      );
    });

    // Python Parity: matches Python auditor strict contamination checks
    group('Python Parity - Strict Contamination Checks', () {
      // 1. Unit patterns from Python DOSAGE_UNIT_PATTERNS
      test('should remove dosage units with numbers (mg, g, ml, ui, %, ch, dh, gbq, mbq)', () {
        expect(sanitizeActivePrinciple('MOLECULE 100 mg'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE 5 g'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE 250 ml'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE 1000 ui'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE 5 %'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE 5CH'), 'MOLECULE'); // Homéopathie
        expect(sanitizeActivePrinciple('MOLECULE 9DH'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE 100 GBq'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE 100 MBq'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE 2,5 mg'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE 0.5 g'), 'MOLECULE');
      });

      // 2. Formulation keywords from Python FORMULATION_KEYWORDS
      test('should remove formulation keywords (comprimé, gélule, solution, injectable, etc.)', () {
        expect(sanitizeActivePrinciple('MOLECULE comprimé'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE gélule'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE injectable'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE sirop'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE suspension'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE crème'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE pommade'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE gel'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE collyre'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE inhalation'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE poudre'), 'MOLECULE');
      });

      // 3. Exception: "solution de" should be preserved (Python FORMULATION_EXCEPTIONS)
      test('should preserve "solution de" as exception', () {
        expect(sanitizeActivePrinciple('SOLUTION DE CHLORHEXIDINE'), 'SOLUTION DE CHLORHEXIDINE');
        expect(sanitizeActivePrinciple('MOLECULE solution de lavage'), 'MOLECULE solution de lavage');
        // But standalone "solution" should be removed
        expect(sanitizeActivePrinciple('MOLECULE solution'), 'MOLECULE');
      });

      // 4. Standalone numbers (Python NUMBER_PATTERN)
      test('should remove standalone numbers except known numbered molecules', () {
        // "MOLECULE 500" -> "MOLECULE" (removed)
        expect(sanitizeActivePrinciple('PARACETAMOL 500'), 'PARACETAMOL');
        expect(sanitizeActivePrinciple('IBUPROFENE 200'), 'IBUPROFENE');
        expect(sanitizeActivePrinciple('MOLECULE 100'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE 2,5'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE 0.5'), 'MOLECULE');
      });

      // 5. Known numbered molecules (Python KNOWN_NUMBERED_MOLECULES)
      test('should preserve known numbered molecules (MACROGOL 4000, HEPARINE 6000, etc.)', () {
        // "PEG 4000" or "HEPARINE 6000" should be preserved
        expect(sanitizeActivePrinciple('MACROGOL 4000'), 'MACROGOL 4000');
        expect(sanitizeActivePrinciple('HEPARINE 6000'), 'HEPARINE 6000');
        expect(sanitizeActivePrinciple('HEPARINE SODIQUE 4000 UI/ML'), contains('4000'));
        expect(sanitizeActivePrinciple('HEPARINE 3350 UI/ML'), contains('3350'));
        // These should preserve the numbers in the molecule name
        expect(sanitizeActivePrinciple('MOLECULE 980'), contains('980'));
        expect(sanitizeActivePrinciple('MOLECULE 940'), contains('940'));
      });

      // 6. Combined contamination patterns
      test('should handle complex contamination patterns', () {
        expect(
          sanitizeActivePrinciple('ESOMEPRAZOLE MAGNESIUM TRIHYDRATE équivalant à ESOMEPRAZOLE 40 mg comprimé'),
          'ESOMEPRAZOLE MAGNESIUM TRIHYDRATE',
        );
        // Note: "pelliculé" is not in the formulation keywords list, so it may remain
        expect(
          sanitizeActivePrinciple('PARACETAMOL 500 mg comprimé'),
          'PARACETAMOL',
        );
        expect(
          sanitizeActivePrinciple('IBUPROFENE 200 mg gélule'),
          'IBUPROFENE',
        );
      });

      // 7. Edge cases with hyphens and special characters
      test('should handle hyphenated numbers (likely part of molecule name)', () {
        // Numbers preceded by hyphen should be preserved
        expect(sanitizeActivePrinciple('MOLECULE-2,4'), 'MOLECULE-2,4');
        expect(sanitizeActivePrinciple('MOLECULE-2.4'), 'MOLECULE-2.4');
      });

      // 8. Multiple contamination sources in one string
      test('should remove all contamination sources in a single string', () {
        // Note: "pelliculé" is not in the formulation keywords list, so it may remain
        expect(
          sanitizeActivePrinciple('PARACETAMOL 500 mg comprimé sirop'),
          'PARACETAMOL',
        );
        expect(
          sanitizeActivePrinciple('IBUPROFENE 200 mg 5 g injectable suspension'),
          'IBUPROFENE',
        );
      });

      // 9. Case-insensitive matching
      test('should handle case-insensitive contamination removal', () {
        expect(sanitizeActivePrinciple('MOLECULE 100 MG'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE 5 G'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE COMPRIMÉ'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE GÉLULE'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE 5CH'), 'MOLECULE');
        expect(sanitizeActivePrinciple('MOLECULE 9DH'), 'MOLECULE');
      });

      // 10. Verify parenthetical content is removed before contamination checks
      test('should remove parenthetical content before contamination checks', () {
        expect(
          sanitizeActivePrinciple('MOLECULE (sel de sodium) 100 mg'),
          'MOLECULE',
        );
        expect(
          sanitizeActivePrinciple('PARACETAMOL (CHLORHYDRATE DE) 500 mg comprimé'),
          'PARACETAMOL',
        );
      });
    });
  });
}

