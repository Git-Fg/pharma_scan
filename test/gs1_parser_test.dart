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

      // THEN: Il doit extraire au moins les champs à longueur fixe
      expect(result.gtin, '3400930302613');
      expect(
        result.lot,
        'MA00614A',
      ); // Notre parser simplifié gère aussi ce cas
      expect(result.expDate, DateTime.utc(2027, 4, 30));
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
  });
}
