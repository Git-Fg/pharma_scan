import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';

void main() {
  group('Sanitizer', () {
    group('normalizeForSearch', () {
      // Hardcoded test vectors derived from backend_pipeline/src/sanitizer.ts
      // These MUST remain perfectly synchronized with the backend implementation

      test('handles basic diacritics removal', () {
        const testCases = {
          'DOLIPRANE®': 'doliprane',
          'Paracétamol': 'paracetamol',
          'Amoxicilline': 'amoxicilline',
          'Acide clavulanique': 'acide clavulanique',
          'Vaccin anti-hépatite B': 'vaccin anti hepatite b',
          'Élévation': 'elevation',
          'ï': 'i',
          'ô': 'o',
        };

        for (final input in testCases.keys) {
          final expected = testCases[input]!;
          final result = Sanitizer.normalizeForSearch(input);
          expect(result, expected, reason: 'Input: "$input"');
        }
      });

      test('converts to lowercase', () {
        const testCases = {
          'DOLIPRANE': 'doliprane',
          'AMOXICILLINE': 'amoxicilline',
          'Paracétamol 500mg': 'paracetamol 500mg',
        };

        for (final input in testCases.keys) {
          final expected = testCases[input]!;
          final result = Sanitizer.normalizeForSearch(input);
          expect(result, expected, reason: 'Input: "$input"');
        }
      });

      test('replaces non-alphanumeric characters with spaces', () {
        const testCases = {
          'DOLIPRANE®': 'doliprane',
          'Amoxicilline/Acide': 'amoxicilline acide',
          'Doliprane-1000mg': 'doliprane 1000mg',
          'IBUPROFENE 400mg': 'ibuprofene 400mg',
          'Paracétamol+Codéine': 'paracetamol codeine',
          'Aspirine®': 'aspirine',
        };

        for (final input in testCases.keys) {
          final expected = testCases[input]!;
          final result = Sanitizer.normalizeForSearch(input);
          expect(result, expected, reason: 'Input: "$input"');
        }
      });

      test('collapses multiple spaces to single space', () {
        const testCases = {
          'doliprane   1000   mg': 'doliprane 1000 mg',
          'paracetamol    500    mg': 'paracetamol 500 mg',
          '  multiple   spaces  between  words  ': 'multiple spaces between words',
        };

        for (final input in testCases.keys) {
          final expected = testCases[input]!;
          final result = Sanitizer.normalizeForSearch(input);
          expect(result, expected, reason: 'Input: "$input"');
        }
      });

      test('trims leading and trailing whitespace', () {
        const testCases = {
          '  doliprane  ': 'doliprane',
          '\tparacetamol 500mg\n': 'paracetamol 500mg',
          '  amoxicilline  ': 'amoxicilline',
        };

        for (final input in testCases.keys) {
          final expected = testCases[input]!;
          final result = Sanitizer.normalizeForSearch(input);
          expect(result, expected, reason: 'Input: "$input"');
        }
      });

      test('handles empty and null inputs', () {
        const testCases = {
          '': '',
          '   ': '',
          '\t\n': '',
        };

        for (final input in testCases.keys) {
          final expected = testCases[input]!;
          final result = Sanitizer.normalizeForSearch(input);
          expect(result, expected, reason: 'Input: "$input"');
        }
      });

      test('comprehensive pharmaceutical examples', () {
        // These are comprehensive test cases that mirror the backend sanitizer examples
        const testCases = {
          'DOLIPRANE®': 'doliprane',
          'Paracétamol 500mg': 'paracetamol 500mg',
          'Amoxicilline/Acide clavulanique': 'amoxicilline acide clavulanique',
          'Vaccin anti-hépatite B (recombinant)': 'vaccin anti hepatite b recombinant',
          'CHLORHYDRATE DE PROPRANOLOL': 'chlorhydrate de propranolol',
          'IBUPROFENE 400 mg, comprimé enrobé': 'ibuprofene 400 mg comprime enrobe',
        };

        for (final input in testCases.keys) {
          final expected = testCases[input]!;
          final result = Sanitizer.normalizeForSearch(input);
          expect(result, expected, reason: 'Input: "$input"');
        }
      });

      test('maintains backend synchronization', () {
        // Critical test: This ensures our implementation matches backend exactly
        // If this test fails, mobile search will break!
        const backendExpectedVectors = {
          // From backend_pipeline/src/sanitizer.ts examples
          'DOLIPRANE®': 'doliprane',
          'Paracétamol 500mg': 'paracetamol 500mg',
          'Amoxicilline/Acide clavulanique': 'amoxicilline acide clavulanique',
        };

        for (final input in backendExpectedVectors.keys) {
          final expected = backendExpectedVectors[input]!;
          final result = Sanitizer.normalizeForSearch(input);
          expect(
            result,
            expected,
            reason: 'CRITICAL: Backend synchronization failure for "$input". '
                    'This will break FTS5 search functionality!',
          );
        }
      });
    });
  });
}