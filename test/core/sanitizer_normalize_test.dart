// test/core/sanitizer_normalize_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';

void main() {
  group('normalizePrincipleOptimal - Mémantine cases', () {
    test('should normalize "MÉMANTINE" to "MEMANTINE"', () {
      final result = normalizePrincipleOptimal('MÉMANTINE');
      expect(result, equals('MEMANTINE'));
    });

    test('should normalize "MÉMANTINE BASE" to "MEMANTINE"', () {
      final result = normalizePrincipleOptimal('MÉMANTINE BASE');
      expect(
        result,
        equals('MEMANTINE'),
        reason: 'BASE suffix should be removed from "MÉMANTINE BASE"',
      );
    });

    test('should normalize "CHLORHYDRATE DE MÉMANTINE" to "MEMANTINE"', () {
      final result = normalizePrincipleOptimal('CHLORHYDRATE DE MÉMANTINE');
      expect(
        result,
        equals('MEMANTINE'),
        reason: 'Salt prefix "CHLORHYDRATE DE" should be removed',
      );
    });

    test('should normalize "MIANSÉRINE (CHLORHYDRATE DE)" correctly', () {
      final result = normalizePrincipleOptimal('MIANSÉRINE (CHLORHYDRATE DE)');
      // The inverse format logic should extract "MIANSERINE" (group 1) since it's not a mineral
      expect(
        result,
        equals('MIANSERINE'),
        reason:
            "Should extract group 1 (MIANSERINE) since it's not a mineral/electrolyte",
      );
    });

    test('should normalize "MÉMANTINE (CHLORHYDRATE DE)" correctly', () {
      final result = normalizePrincipleOptimal('MÉMANTINE (CHLORHYDRATE DE)');
      // The inverse format logic should extract "MEMANTINE" (group 1) since it's not a mineral
      expect(
        result,
        equals('MEMANTINE'),
        reason:
            "Should extract group 1 (MEMANTINE) since it's not a mineral/electrolyte",
      );
    });

    test('should normalize "SODIUM (VALPROATE DE)" correctly', () {
      final result = normalizePrincipleOptimal('SODIUM (VALPROATE DE)');
      // The inverse format logic should extract "VALPROATE" (group 2) since SODIUM is a mineral
      expect(
        result,
        equals('VALPROATE'),
        reason:
            'Should extract group 2 (VALPROATE) since SODIUM is a mineral/electrolyte',
      );
    });

    test('should normalize "CHLORHYDRATE DE MIANSÉRINE" correctly', () {
      final result = normalizePrincipleOptimal('CHLORHYDRATE DE MIANSÉRINE');
      expect(result, isNotEmpty);
      expect(result, contains('MIANSERINE'));
    });
  });
}
