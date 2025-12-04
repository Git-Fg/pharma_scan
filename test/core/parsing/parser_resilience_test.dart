// test/core/parsing/parser_resilience_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart'
    show BdpmFileParser, EmptyContentError;

Stream<String> _streamFromContent(String content) =>
    Stream<String>.value(content).transform(const LineSplitter());

void main() {
  group('BDPM Parser Resilience Tests', () {
    test('handles invalid date format gracefully', () async {
      const content = '''
60002283\tSPECIALITE\tComprimé\torale\tAutorisation active\tProcédure A\tCommercialisé\t32/13/2024\tstatutbdm\tEU9999\tLab Active\tNon
''';

      final resultEither = await BdpmFileParser.parseSpecialites(
        _streamFromContent(content),
        const <String, String>{},
        const <String, String>{},
      );

      expect(
        resultEither.isRight,
        isTrue,
        reason:
            'Parser should not throw on invalid date, should continue parsing',
      );

      resultEither.fold(
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (result) {
          expect(
            result.specialites,
            isNotEmpty,
            reason: 'Should parse valid parts even with invalid date',
          );
        },
      );
    });

    test('handles invalid price format gracefully', () async {
      const content = '''
60002283\tSPECIALITE\tComprimé\torale\tAutorisation active\tProcédure A\tCommercialisé\t01/01/2024\tstatutbdm\tEU9999\tLab Active\tNon
60002283\t\t\t\t\t\t\t\t\t\t\t\t3400930302613\t\t12.34.56\t\t
''';

      final specialitesResult = await BdpmFileParser.parseSpecialites(
        _streamFromContent(content),
        const <String, String>{},
        const <String, String>{},
      );

      final specialites = specialitesResult.fold(
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (result) => result,
      );

      final medicamentsResult = await BdpmFileParser.parseMedicaments(
        _streamFromContent(
          '60002283\t\t\t\t\t\t\t\t\t\t\t\t3400930302613\t\t12.34.56\t\t',
        ),
        specialites,
      );

      expect(
        medicamentsResult.isRight,
        isTrue,
        reason: 'Parser should not throw on invalid price format',
      );

      medicamentsResult.fold(
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (result) {
          expect(
            result.medicaments,
            isNotEmpty,
            reason: 'Should parse valid parts even with invalid price',
          );
          final medicament = result.medicaments.firstWhere(
            (m) => m.codeCip == '3400930302613',
          );
          expect(
            medicament.prixPublic,
            isNull,
            reason: 'Invalid price should result in null prixPublic',
          );
        },
      );
    });

    test('handles missing columns gracefully', () async {
      const content = '''
60002283\tSPECIALITE\tComprimé
''';

      final resultEither = await BdpmFileParser.parseSpecialites(
        _streamFromContent(content),
        const <String, String>{},
        const <String, String>{},
      );

      expect(
        resultEither.isRight,
        isTrue,
        reason: 'Parser should not throw on missing columns',
      );

      resultEither.fold(
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (result) {
          expect(
            result.specialites,
            isEmpty,
            reason: 'Line with insufficient columns should be skipped',
          );
        },
      );
    });

    test('handles UTF-8 encoded content gracefully', () async {
      const content =
          '60002283\tSPÉCIALITÉ\tComprimé\torale\tAutorisation active\tProcédure A\tCommercialisé\t01/01/2024\tstatutbdm\tEU9999\tLab Active\tNon';

      final resultEither = await BdpmFileParser.parseSpecialites(
        _streamFromContent(content),
        const <String, String>{},
        const <String, String>{},
      );

      expect(
        resultEither.isRight,
        isTrue,
        reason: 'Parser should handle UTF-8 encoded content',
      );

      resultEither.fold(
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (result) {
          expect(
            result.specialites,
            isNotEmpty,
            reason: 'Should parse UTF-8 encoded content',
          );
        },
      );
    });

    test('handles empty stream gracefully', () async {
      final resultEither = await BdpmFileParser.parseSpecialites(
        _streamFromContent(''),
        const <String, String>{},
        const <String, String>{},
      );

      expect(
        resultEither.isLeft,
        isTrue,
        reason: 'Empty stream should return Either.left',
      );

      resultEither.fold(
        ifLeft: (error) {
          expect(
            error,
            isA<EmptyContentError>(),
            reason: 'Empty stream should return EmptyContentError',
          );
          expect(
            (error as EmptyContentError).fileName,
            equals('specialites'),
            reason: 'Error should indicate specialites file',
          );
        },
        ifRight: (_) => fail('Expected error but got success'),
      );
    });

    test('handles malformed composition lines gracefully', () async {
      const content = '''
60002283	comprimé	42215	ANASTROZOLE	1,00 mg	un comprimé	SA	1
60002283	comprimé	42215
60002283	comprimé	42215	ANASTROZOLE
''';

      final cisToCip13 = {
        '60002283': ['3400930302613'],
      };

      final resultEither = await BdpmFileParser.parseCompositions(
        _streamFromContent(content),
        cisToCip13,
      );

      expect(
        resultEither.isRight,
        isTrue,
        reason: 'Parser should not throw on malformed composition lines',
      );

      resultEither.fold(
        ifLeft: (error) => fail('Expected success but got error: $error'),
        ifRight: (result) {
          expect(
            result.length,
            equals(1),
            reason: 'Should parse only valid composition lines',
          );
        },
      );
    });

    test('handles null stream gracefully', () async {
      final resultEither = await BdpmFileParser.parseSpecialites(
        null,
        const <String, String>{},
        const <String, String>{},
      );

      expect(
        resultEither.isLeft,
        isTrue,
        reason: 'Null stream should return Either.left',
      );

      resultEither.fold(
        ifLeft: (error) {
          expect(
            error,
            isA<EmptyContentError>(),
            reason: 'Null stream should return EmptyContentError',
          );
          expect(
            (error as EmptyContentError).fileName,
            equals('specialites'),
            reason: 'Error should indicate specialites file',
          );
        },
        ifRight: (_) => fail('Expected error but got success'),
      );
    });
  });
}
