// test/core/parser/medicament_parser_test.dart

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/parser/medicament_grammar.dart';

void main() {
  group('MedicamentParser', () {
    final parser = MedicamentParser();

    test('extracts base name, dosage, and formulation', () {
      const raw = 'DOLIPRANE 500 mg, comprimé sécable';
      final result = parser.parse(raw);

      expect(result.baseName, 'DOLIPRANE');
      expect(result.formulation, 'comprimé sécable');
      expect(result.dosages, isNotEmpty);
      expect(result.dosages.first.value, Decimal.fromInt(500));
      expect(result.dosages.first.unit.toLowerCase(), 'mg');
    });

    test('handles ratio dosages', () {
      const raw = 'CADUET 5 mg/10 mg, comprimé';
      final result = parser.parse(raw);

      expect(result.baseName, 'CADUET');
      expect(result.dosages.length, 1);
      expect(result.dosages.first.isRatio, isTrue);
      expect(result.dosages.first.unit.toLowerCase(), 'mg/10 mg');
    });

    test('strips known laboratory suffix', () {
      const raw = 'AMOXICILLINE TEVA 1 g, poudre pour solution injectable';
      final result = parser.parse(raw);

      expect(result.baseName, 'AMOXICILLINE');
      expect(result.formulation, 'poudre pour solution injectable');
    });

    test('prefers the longest matching formulation keyword', () {
      const raw = 'PODIUM 250 mg, poudre pour suspension buvable en flacon';
      final result = parser.parse(raw);

      expect(result.formulation, 'poudre pour suspension buvable en flacon');
      expect(result.baseName, 'PODIUM');
    });

    test('removes trailing measurement artifacts like /24 heures', () {
      const raw = 'BETADINE 10 mg/24 heures';
      final result = parser.parse(raw);

      expect(result.baseName, 'BETADINE s');
      expect(result.baseName!.contains('/24 heures'), isFalse);
      expect(result.dosages.single.raw, '10 mg/24 heure');
    });

    test('keeps LP suffix after stripping lab names', () {
      const raw = 'AMLODIPINE TEVA 5 mg LP, comprimé';
      final result = parser.parse(raw);

      expect(result.baseName, 'AMLODIPINE LP');
      expect(result.formulation, 'comprimé');
    });

    test('deduplicates repeated dosages to avoid noise', () {
      const raw = 'NULOID 500 mg 500 mg, comprimé';
      final result = parser.parse(raw);

      expect(result.dosages.length, 1);
      expect(result.dosages.first.value, Decimal.fromInt(500));
    });

    test('returns empty parsing information for blank strings', () {
      final result = parser.parse('   ');

      expect(result.baseName, isNull);
      expect(result.dosages, isEmpty);
      expect(result.formulation, isNull);
    });
  });
}
