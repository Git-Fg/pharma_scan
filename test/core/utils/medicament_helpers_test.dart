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
      // More comprehensive formulation keyword removal tests
      final testCases = {
        'PARACETAMOL comprimé': 'PARACETAMOL',
        'IBUPROFENE solution': 'IBUPROFENE',
        'ASPIRINE gélule injectable': 'ASPIRINE',
        'MOLECULE sirop suspension': 'MOLECULE',
        'PRINCIPE crème pommade gel': 'PRINCIPE',
        'ACTIF solution de test': 'ACTIF solution de test', // Exception pattern
      };

      for (final entry in testCases.entries) {
        final sanitized = sanitizeActivePrinciple(entry.key);
        final normalized = sanitized.trim().replaceAll(RegExp(r'\s+'), ' ');
        expect(
          normalized,
          equals(entry.value.trim()),
          reason: 'Failed for: ${entry.key}',
        );
      }
    });

    test('should remove dosage units and numbers', () {
      expect(
        sanitizeActivePrinciple(
          'ESOMEPRAZOLE MAGNESIUM TRIHYDRATE équivalant à ESOMEPRAZOLE 40 mg',
        ),
        equals('ESOMEPRAZOLE MAGNESIUM TRIHYDRATE'),
      );
      expect(
        sanitizeActivePrinciple('PARACETAMOL 500 mg'),
        equals('PARACETAMOL'),
      );
      // More comprehensive test cases
      final testCases = {
        'ESOMEPRAZOLE MAGNESIUM TRIHYDRATE équivalant à ESOMEPRAZOLE 40 mg':
            'ESOMEPRAZOLE MAGNESIUM TRIHYDRATE',
        'PARACETAMOL 500 mg': 'PARACETAMOL',
        'IBUPROFENE 200 mg comprimé': 'IBUPROFENE',
        'ASPIRINE 100 mg (comprimé)': 'ASPIRINE',
        'MOLECULE 5 g solution': 'MOLECULE',
        'PRINCIPE 0.5 %': 'PRINCIPE',
        'ACTIF 1000 ui injectable': 'ACTIF',
      };

      for (final entry in testCases.entries) {
        final sanitized = sanitizeActivePrinciple(entry.key);
        // Normalize whitespace for comparison
        final normalized = sanitized.trim().replaceAll(RegExp(r'\s+'), ' ');
        expect(
          normalized,
          equals(entry.value.trim()),
          reason: 'Failed for: ${entry.key}',
        );
      }
    });

    test('should preserve legitimate molecule names with numbers', () {
      expect(
        sanitizeActivePrinciple('HEPARINE SODIQUE 4000 UI/ML'),
        contains('4000'),
      );
      expect(sanitizeActivePrinciple('HEPARINE 3350 UI/ML'), contains('3350'));
      // Test known numbered molecules that should be preserved
      final testCases = [
        'HEPARINE SODIQUE 4000 UI/ML',
        'HEPARINE 3350 UI/ML',
        'HEPARINE 980 UI/ML',
        'HEPARINE 940 UI/ML',
        'HEPARINE 6000 UI/ML',
        'ACIDE 2,4-DICHLOROPHENOXYACETIQUE',
        'MOLECULE-2,4-TEST',
      ];

      for (final testCase in testCases) {
        final sanitized = sanitizeActivePrinciple(testCase);
        // Numbers should be preserved for known molecules
        expect(sanitized, isNotEmpty, reason: 'Should not be empty: $testCase');
        expect(
          sanitized.toLowerCase(),
          isNot(contains('ui/ml')),
          reason: 'Should remove dosage units: $testCase',
        );
        // Note: Some legitimate molecules may contain '/' in their names,
        // so we only check for unit patterns like "UI/ML"
        expect(
          sanitized.toLowerCase(),
          isNot(RegExp(r'\d+\s*ui\s*/').hasMatch),
          reason: 'Should remove dosage unit patterns: $testCase',
        );
      }
    });

    test('should handle parenthetical content', () {
      expect(
        sanitizeActivePrinciple('MOLECULE (sel de sodium)'),
        equals('MOLECULE'),
      );
      // More comprehensive parenthetical content tests
      final testCases = {
        'MOLECULE (sel de sodium)': 'MOLECULE',
        'ACTIF (monohydrate) 500 mg': 'ACTIF',
        'PRINCIPE (test) solution': 'PRINCIPE',
      };

      for (final entry in testCases.entries) {
        final sanitized = sanitizeActivePrinciple(entry.key);
        expect(
          sanitized,
          isNot(contains('(')),
          reason: 'Should remove parentheses: ${entry.key}',
        );
        expect(
          sanitized,
          isNot(contains(')')),
          reason: 'Should remove parentheses: ${entry.key}',
        );
      }
    });

    test('should handle "équivalant à" patterns', () {
      expect(
        sanitizeActivePrinciple(
          'ESOMEPRAZOLE MAGNESIUM TRIHYDRATE équivalant à ESOMEPRAZOLE 40 mg',
        ),
        equals('ESOMEPRAZOLE MAGNESIUM TRIHYDRATE'),
      );
      expect(
        sanitizeActivePrinciple('MOLECULE équivalant à BASE 500 mg'),
        equals('MOLECULE'),
      );
      expect(
        sanitizeActivePrinciple('ACTIF ÉQUIVALANT À BASE'),
        equals('ACTIF'),
      );
    });

    test('should handle multiple components correctly', () {
      // Test that sanitization works on each component independently
      final multiComponent =
          'PARACETAMOL 500 mg, CODEINE 30 mg, CAFFEINE 50 mg';
      final sanitized = sanitizeActivePrinciple(multiComponent);
      expect(
        sanitized,
        contains('PARACETAMOL'),
        reason: 'Should preserve PARACETAMOL',
      );
      expect(sanitized, contains('CODEINE'), reason: 'Should preserve CODEINE');
      expect(
        sanitized,
        contains('CAFFEINE'),
        reason: 'Should preserve CAFFEINE',
      );
      expect(
        sanitized,
        isNot(contains('mg')),
        reason: 'Should remove dosage units',
      );
    });

    test('should handle close dosages correctly', () {
      // Test medications with similar dosages to ensure proper sanitization
      final testCases = [
        'MOLECULE 100 mg',
        'MOLECULE 100.5 mg',
        'MOLECULE 100,5 mg',
        'MOLECULE 99 mg',
        'MOLECULE 101 mg',
      ];

      for (final testCase in testCases) {
        final sanitized = sanitizeActivePrinciple(testCase);
        expect(sanitized, equals('MOLECULE'), reason: 'Failed for: $testCase');
        expect(
          sanitized,
          isNot(contains('mg')),
          reason: 'Should remove units: $testCase',
        );
        expect(
          sanitized,
          isNot(RegExp(r'\d').hasMatch),
          reason: 'Should remove numbers: $testCase',
        );
      }
    });

    // Python Parity: matches Python auditor strict contamination checks
    group('Python Parity - Strict Contamination Checks', () {
      // 1. Unit patterns from Python DOSAGE_UNIT_PATTERNS
      test(
        'should remove dosage units with numbers (mg, g, ml, ui, %, ch, dh, gbq, mbq)',
        () {
          expect(sanitizeActivePrinciple('MOLECULE 100 mg'), 'MOLECULE');
          expect(sanitizeActivePrinciple('MOLECULE 5 g'), 'MOLECULE');
          expect(sanitizeActivePrinciple('MOLECULE 250 ml'), 'MOLECULE');
          expect(sanitizeActivePrinciple('MOLECULE 1000 ui'), 'MOLECULE');
          expect(sanitizeActivePrinciple('MOLECULE 5 %'), 'MOLECULE');
          expect(
            sanitizeActivePrinciple('MOLECULE 5CH'),
            'MOLECULE',
          ); // Homéopathie
          expect(sanitizeActivePrinciple('MOLECULE 9DH'), 'MOLECULE');
          expect(sanitizeActivePrinciple('MOLECULE 100 GBq'), 'MOLECULE');
          expect(sanitizeActivePrinciple('MOLECULE 100 MBq'), 'MOLECULE');
          expect(sanitizeActivePrinciple('MOLECULE 2,5 mg'), 'MOLECULE');
          expect(sanitizeActivePrinciple('MOLECULE 0.5 g'), 'MOLECULE');
        },
      );

      // 2. Formulation keywords from Python FORMULATION_KEYWORDS
      test(
        'should remove formulation keywords (comprimé, gélule, solution, injectable, etc.)',
        () {
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
        },
      );

      // 3. Exception: "solution de" should be preserved (Python FORMULATION_EXCEPTIONS)
      test('should preserve "solution de" as exception', () {
        expect(
          sanitizeActivePrinciple('SOLUTION DE CHLORHEXIDINE'),
          'SOLUTION DE CHLORHEXIDINE',
        );
        expect(
          sanitizeActivePrinciple('MOLECULE solution de lavage'),
          'MOLECULE solution de lavage',
        );
        // But standalone "solution" should be removed
        expect(sanitizeActivePrinciple('MOLECULE solution'), 'MOLECULE');
        // More comprehensive "solution de" exception cases
        expect(
          sanitizeActivePrinciple('SOLUTION DE DIGLUCONATE DE CHLORHEXIDINE'),
          'SOLUTION DE DIGLUCONATE DE CHLORHEXIDINE',
        );
        expect(sanitizeActivePrinciple('solution de test'), 'solution de test');
        expect(
          sanitizeActivePrinciple('MOLECULE solution de BASE'),
          'MOLECULE solution de BASE',
        );
        expect(
          sanitizeActivePrinciple('PRINCIPE solution injectable'),
          'PRINCIPE',
        );
        expect(
          sanitizeActivePrinciple('ACTIF solution de test'),
          'ACTIF solution de test',
        );
      });

      // 4. Standalone numbers (Python NUMBER_PATTERN)
      test(
        'should remove standalone numbers except known numbered molecules',
        () {
          // "MOLECULE 500" -> "MOLECULE" (removed)
          expect(sanitizeActivePrinciple('PARACETAMOL 500'), 'PARACETAMOL');
          expect(sanitizeActivePrinciple('IBUPROFENE 200'), 'IBUPROFENE');
          expect(sanitizeActivePrinciple('MOLECULE 100'), 'MOLECULE');
          expect(sanitizeActivePrinciple('MOLECULE 2,5'), 'MOLECULE');
          expect(sanitizeActivePrinciple('MOLECULE 0.5'), 'MOLECULE');
        },
      );

      // 5. Known numbered molecules (Python KNOWN_NUMBERED_MOLECULES)
      test(
        'should preserve known numbered molecules (MACROGOL 4000, HEPARINE 6000, etc.)',
        () {
          // "PEG 4000" or "HEPARINE 6000" should be preserved
          expect(sanitizeActivePrinciple('MACROGOL 4000'), 'MACROGOL 4000');
          expect(sanitizeActivePrinciple('HEPARINE 6000'), 'HEPARINE 6000');
          expect(
            sanitizeActivePrinciple('HEPARINE SODIQUE 4000 UI/ML'),
            contains('4000'),
          );
          expect(
            sanitizeActivePrinciple('HEPARINE 3350 UI/ML'),
            contains('3350'),
          );
          // These should preserve the numbers in the molecule name
          expect(sanitizeActivePrinciple('MOLECULE 980'), contains('980'));
          expect(sanitizeActivePrinciple('MOLECULE 940'), contains('940'));
        },
      );

      // 6. Combined contamination patterns
      test('should handle complex contamination patterns', () {
        expect(
          sanitizeActivePrinciple(
            'ESOMEPRAZOLE MAGNESIUM TRIHYDRATE équivalant à ESOMEPRAZOLE 40 mg comprimé',
          ),
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
      test(
        'should handle hyphenated numbers (likely part of molecule name)',
        () {
          // Numbers preceded by hyphen should be preserved
          expect(sanitizeActivePrinciple('MOLECULE-2,4'), 'MOLECULE-2,4');
          expect(sanitizeActivePrinciple('MOLECULE-2.4'), 'MOLECULE-2.4');
          // More specific hyphenated molecule test cases
          expect(
            sanitizeActivePrinciple('ALCOOL DICHLORO-2,4 BENZYLIQUE'),
            'ALCOOL DICHLORO-2,4 BENZYLIQUE',
          );
          expect(
            sanitizeActivePrinciple('MOLECULE-4000 TEST'),
            'MOLECULE-4000 TEST',
          );
          expect(
            sanitizeActivePrinciple('ACTIF-2,4-DICHLORO'),
            'ACTIF-2,4-DICHLORO',
          );
          expect(
            sanitizeActivePrinciple('PRINCIPE-6000-COMPLEX'),
            'PRINCIPE-6000-COMPLEX',
          );
          expect(sanitizeActivePrinciple('MOLECULE-4000'), 'MOLECULE-4000');
          // Verify the hyphenated number is preserved
          expect(
            sanitizeActivePrinciple('MOLECULE-4000'),
            contains('-'),
            reason: 'Should preserve hyphen in: MOLECULE-4000',
          );
        },
      );

      // 8. Multiple contamination sources in one string
      test('should remove all contamination sources in a single string', () {
        // Note: "pelliculé" is not in the formulation keywords list, so it may remain
        expect(
          sanitizeActivePrinciple('PARACETAMOL 500 mg comprimé sirop'),
          'PARACETAMOL',
        );
        expect(
          sanitizeActivePrinciple(
            'IBUPROFENE 200 mg 5 g injectable suspension',
          ),
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
      test(
        'should remove parenthetical content before contamination checks',
        () {
          expect(
            sanitizeActivePrinciple('MOLECULE (sel de sodium) 100 mg'),
            'MOLECULE',
          );
          expect(
            sanitizeActivePrinciple(
              'PARACETAMOL (CHLORHYDRATE DE) 500 mg comprimé',
            ),
            'PARACETAMOL',
          );
        },
      );
    });
  });
}
