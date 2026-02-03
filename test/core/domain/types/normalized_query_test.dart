import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';

void main() {
  group('NormalizedQuery', () {
    test('Preserves diacritics (handled by SQLite)', () {
      const input = 'Paracétamol';
      final result = NormalizedQuery.fromString(input);

      expect(result, 'Paracétamol');
    });

    test('Preserves case (handled by SQLite)', () {
      const input = 'DOLIPRANE';
      final result = NormalizedQuery.fromString(input);

      expect(result, 'DOLIPRANE');
    });

    test('Trims whitespace', () {
      const input = '  amoxicilline  ';
      final result = NormalizedQuery.fromString(input);

      expect(result, 'amoxicilline');
    });

    // Thin Client: We do NOT normalize internal whitespace anymore
    test('Preserves internal whitespace', () {
      const input = 'doliprane   1000   mg';
      final result = NormalizedQuery.fromString(input);

      expect(result, 'doliprane   1000   mg');
    });

    test('Returns empty string for empty input', () {
      final result1 = NormalizedQuery.fromString('');
      final result2 = NormalizedQuery.fromString('   ');

      expect(result1, '');
      expect(result2, '');
    });

    test('Preserves special characters', () {
      const input = 'DOLIPRANE®';
      final result = NormalizedQuery.fromString(input);

      expect(result, 'DOLIPRANE®');
    });

    test('Preserves complex characters', () {
      const input = 'Amoxicilline/Acide clavulanique';
      final result = NormalizedQuery.fromString(input);

      expect(result, 'Amoxicilline/Acide clavulanique');
    });

    test('Preserves salt prefixes', () {
      const input = 'Chlorhydrate de Paracétamol';
      final result = NormalizedQuery.fromString(input);

      expect(result, 'Chlorhydrate de Paracétamol');
    });

    test('Converts normalized query to FTS query string', () {
      final q = NormalizedQuery.fromString('doliprane 1000 mg');
      // Thin Client: Enclose in quotes for trigram phrase matching
      expect(q.toFtsQuery(), '"doliprane 1000 mg"');
    });

    test('Empty normalized query returns empty quoted string', () {
      // Logic in semantic_types.dart: returns '"$_value"'
      // If value is empty, it returns '""'.
      final q = NormalizedQuery.fromString('   ');
      expect(q.toFtsQuery(), '""');
    });
  });
}
