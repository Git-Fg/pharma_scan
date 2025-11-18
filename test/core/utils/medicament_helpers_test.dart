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
  });
}

