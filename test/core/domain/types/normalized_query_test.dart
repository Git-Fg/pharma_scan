import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';

void main() {
  group('NormalizedQuery', () {
    test('Normalizes diacritics correctly', () {
      const input = 'Paracétamol';
      final result = NormalizedQuery.fromString(input);

      expect(result, 'paracetamol');
    });

    test('Converts to lowercase', () {
      const input = 'DOLIPRANE';
      final result = NormalizedQuery.fromString(input);

      expect(result, 'doliprane');
    });

    test('Trims whitespace', () {
      const input = '  amoxicilline  ';
      final result = NormalizedQuery.fromString(input);

      expect(result, 'amoxicilline');
    });

    test('Replaces multiple spaces with single space', () {
      const input = 'doliprane   1000   mg';
      final result = NormalizedQuery.fromString(input);

      expect(result, 'doliprane 1000 mg');
    });

    test('Returns empty string for empty input', () {
      final result1 = NormalizedQuery.fromString('');
      final result2 = NormalizedQuery.fromString('   ');

      expect(result1, '');
      expect(result2, '');
    });

    test('Replaces non-alphanumeric characters with spaces', () {
      const input = 'DOLIPRANE®';
      final result = NormalizedQuery.fromString(input);

      expect(result, 'doliprane');
    });

    test('Handles complex pharmaceutical names with accents and symbols', () {
      const input = 'Amoxicilline/Acide clavulanique';
      final result = NormalizedQuery.fromString(input);

      expect(result, 'amoxicilline acide clavulanique');
    });

    test('Preserves pharmaceutical terms with salts', () {
      const input = 'Chlorhydrate de Paracétamol';
      final result = NormalizedQuery.fromString(input);

      expect(result, 'chlorhydrate de paracetamol');
    });

    test('Converts normalized query to FTS query string', () {
      final q = NormalizedQuery.fromString('doliprane 1000 mg');
      expect(q.toFtsQuery(), '"doliprane" AND "1000" AND "mg"');
    });

    test('Empty normalized query returns empty FTS string', () {
      final q = NormalizedQuery.fromString('   ');
      expect(q.toFtsQuery(), '');
    });

    test('Uses canonical sanitizer normalization', () {
      // Test that NormalizedQuery delegates to Sanitizer.normalizeForSearch
      // These are the exact same test cases that should be in the sanitizer test
      const input = 'DOLIPRANE® 500mg';
      final result = NormalizedQuery.fromString(input);

      expect(result, 'doliprane 500mg');
    });
  });
}
