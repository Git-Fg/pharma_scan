import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';

void main() {
  group('Sanitizer', () {
    group('normalizeForSearch (Thin Client)', () {
      // Thin Client Policy:
      // No client-side normalization except basic trimming.
      // All fuzzy matching is handled by SQLite FTS5 backend.

      test('preserves basic diacritics (handled by SQLite)', () {
        const testCases = {
          'DOLIPRANE®': 'DOLIPRANE®',
          'Paracétamol': 'Paracétamol',
          'Amoxicilline': 'Amoxicilline',
          'Acide clavulanique': 'Acide clavulanique',
          'Vaccin anti-hépatite B': 'Vaccin anti-hépatite B',
          'Élévation': 'Élévation',
        };

        for (final input in testCases.keys) {
          final expected = testCases[input]!;
          final result = Sanitizer.normalizeForSearch(input);
          expect(result, expected, reason: 'Input: "$input"');
        }
      });

      test('preserves case (handled by SQLite)', () {
        const testCases = {
          'DOLIPRANE': 'DOLIPRANE',
          'AMOXICILLINE': 'AMOXICILLINE',
          'Paracétamol 500mg': 'Paracétamol 500mg',
        };

        for (final input in testCases.keys) {
          final expected = testCases[input]!;
          final result = Sanitizer.normalizeForSearch(input);
          expect(result, expected, reason: 'Input: "$input"');
        }
      });

      test('preserves special strings and punctuation', () {
        const testCases = {
          'DOLIPRANE®': 'DOLIPRANE®',
          'Amoxicilline/Acide': 'Amoxicilline/Acide',
          'Doliprane-1000mg': 'Doliprane-1000mg',
          'IBUPROFENE 400mg': 'IBUPROFENE 400mg',
          'Paracétamol+Codéine': 'Paracétamol+Codéine',
          'Aspirine®': 'Aspirine®',
        };

        for (final input in testCases.keys) {
          final expected = testCases[input]!;
          final result = Sanitizer.normalizeForSearch(input);
          expect(result, expected, reason: 'Input: "$input"');
        }
      });

      test(
          'preserves multiple spaces (handled by FTS phrase matching or ignored)',
          () {
        const testCases = {
          'doliprane   1000   mg': 'doliprane   1000   mg',
          'paracetamol    500    mg': 'paracetamol    500    mg',
        };

        // Note: FTS5 standard tokenizer might treat multiple spaces as one separator,
        // but client side we just pass it through.
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
    });
  });
}
