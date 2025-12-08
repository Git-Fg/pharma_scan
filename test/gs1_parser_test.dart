import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/utils/gs1_parser.dart';

void main() {
  group('Gs1Parser (Optimisé)', () {
    // Cas nominal fourni
    const rawValueFromTool =
        '01034009303026132132780924334799 10MA00614A 17270430';

    test(
      'devrait parser correctement une chaîne brute avec des espaces comme séparateurs',
      () {
        // WHEN
        final result = Gs1Parser.parse(rawValueFromTool);

        // THEN
        expect(result.gtin, '3400930302613');
        expect(result.serial, '32780924334799');
        expect(result.lot, 'MA00614A');
        expect(result.expDate, DateTime.utc(2027, 4, 30));
      },
    );

    test('devrait accepter le séparateur placeholder |', () {
      const rawValue = '0103400930302613|2132780924334799|10MA00614A|17270430';

      final result = Gs1Parser.parse(rawValue);

      expect(result.gtin, equals('3400930302613'));
      expect(result.serial, equals('32780924334799'));
      expect(result.lot, equals('MA00614A'));
      expect(result.expDate, equals(DateTime.utc(2027, 4, 30)));
    });

    test(
      'devrait parser correctement une chaîne brute avec le vrai caractère FNC1',
      () {
        // GIVEN
        const rawValueWithFNC1 =
            '\u001d01034009303026132132780924334799\u001d10MA00614A\u001d17270430';

        // WHEN
        final result = Gs1Parser.parse(rawValueWithFNC1);

        // THEN
        expect(result.gtin, '3400930302613');
        expect(result.serial, '32780924334799');
        expect(result.lot, 'MA00614A');
        expect(result.expDate, DateTime.utc(2027, 4, 30));
      },
    );

    test('devrait gérer une chaîne malformée sans séparateurs', () {
      // GIVEN: Une chaîne concaténée que certains vieux scanners pourraient produire
      const rawValueConcatenated = '010340093030261310MA00614A17270430';

      // WHEN
      final result = Gs1Parser.parse(rawValueConcatenated);

      // THEN: Le lot englobe le reste en l'absence de séparateurs
      expect(result.gtin, '3400930302613');
      expect(result.lot, 'MA00614A17270430');
      expect(result.expDate, isNull);
    });

    test(
      'devrait retourner des champs nuls pour une chaîne invalide ou vide',
      () {
        // GIVEN: une chaîne vide
        // WHEN: on parse
        final result = Gs1Parser.parse('');

        // THEN: tous les champs sont nuls
        expect(result.gtin, isNull);
        expect(result.serial, isNull);
        expect(result.lot, isNull);
        expect(result.expDate, isNull);
      },
    );

    test('devrait parser null correctement', () {
      final result = Gs1Parser.parse(null);

      expect(result.gtin, isNull);
      expect(result.serial, isNull);
      expect(result.lot, isNull);
      expect(result.expDate, isNull);
    });

    test('devrait parser GTIN seul', () {
      const rawValue = '0103400930302613';
      final result = Gs1Parser.parse(rawValue);

      expect(result.gtin, equals('3400930302613'));
      expect(result.serial, isNull);
      expect(result.lot, isNull);
      expect(result.expDate, isNull);
    });

    test("devrait parser date d'expiration seule", () {
      const rawValue = '17270430';
      final result = Gs1Parser.parse(rawValue);

      expect(result.gtin, isNull);
      expect(result.serial, isNull);
      expect(result.lot, isNull);
      expect(result.expDate, equals(DateTime.utc(2027, 4, 30)));
    });

    test('devrait parser lot seul', () {
      const rawValue = '10MA00614A';
      final result = Gs1Parser.parse(rawValue);

      expect(result.gtin, isNull);
      expect(result.serial, isNull);
      expect(result.lot, equals('MA00614A'));
      expect(result.expDate, isNull);
    });

    test('devrait parser numéro de série seul', () {
      const rawValue = '2132780924334799';
      final result = Gs1Parser.parse(rawValue);

      expect(result.gtin, isNull);
      expect(result.serial, equals('32780924334799'));
      expect(result.lot, isNull);
      expect(result.expDate, isNull);
    });

    test('devrait parser date avec année < 50 (2000+)', () {
      const rawValue = '17230430';
      final result = Gs1Parser.parse(rawValue);

      expect(result.expDate, equals(DateTime.utc(2023, 4, 30)));
    });

    test('devrait parser date avec année >= 50 (1900+)', () {
      const rawValue = '17990430';
      final result = Gs1Parser.parse(rawValue);

      expect(result.expDate, equals(DateTime.utc(1999, 4, 30)));
    });

    test('devrait gérer date invalide', () {
      const rawValue = '17XX0430';
      final result = Gs1Parser.parse(rawValue);

      expect(result.expDate, isNull);
    });

    test('devrait gérer date avec longueur incorrecte', () {
      const rawValue = '17230';
      final result = Gs1Parser.parse(rawValue);

      expect(result.expDate, isNull);
    });

    test('ne doit pas tronquer un lot contenant un motif d’AI', () {
      const rawValue = '10LOT17B|17270430';

      final result = Gs1Parser.parse(rawValue);

      expect(result.lot, equals('LOT17B'));
      expect(result.expDate, equals(DateTime.utc(2027, 4, 30)));
    });

    test('doit interpréter un jour 00 comme dernier jour du mois', () {
      const rawValue = '17231200';

      final result = Gs1Parser.parse(rawValue);

      expect(result.expDate, equals(DateTime.utc(2023, 12, 31)));
    });

    test('doit parser la date de fabrication (AI 11)', () {
      const rawValue = '11231201';

      final result = Gs1Parser.parse(rawValue);

      expect(result.manufacturingDate, equals(DateTime.utc(2023, 12)));
    });

    test('devrait parser tous les champs combinés', () {
      const rawValue =
          '01034009303026132132780924334799\u001d10MA00614A\u001d17270430';
      final result = Gs1Parser.parse(rawValue);

      expect(result.gtin, equals('3400930302613'));
      expect(result.serial, equals('32780924334799'));
      expect(result.lot, equals('MA00614A'));
      expect(result.expDate, equals(DateTime.utc(2027, 4, 30)));
    });

    test('devrait ignorer les AI supplémentaires sans corrompre les champs', () {
      const rawValue =
          '0103400930302613\u001d9100INTERNAL\u001d2132780924334799\u001d10MA00614A\u001d17270430';
      final result = Gs1Parser.parse(rawValue);

      expect(result.gtin, equals('3400930302613'));
      expect(result.serial, equals('32780924334799'));
      expect(result.lot, equals('MA00614A'));
      expect(result.expDate, equals(DateTime.utc(2027, 4, 30)));
    });

    test('devrait ignorer les AI inconnus', () {
      const rawValue = '9901234567890103400930302613';
      final result = Gs1Parser.parse(rawValue);

      expect(result.gtin, equals('3456789010340'));
    });
  });
}
