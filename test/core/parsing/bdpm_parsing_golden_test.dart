// test/core/parsing/bdpm_parsing_golden_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart'
    show BdpmFileParser, ParseError, PrincipeRow;

void main() {
  group('BDPM Parsing Golden Test', () {
    test(
      'parses sample BDPM file and matches expected output',
      () async {
        final sampleFile = File('tool/data/sample_bdpm_compo.txt');
        expect(
          await sampleFile.exists(),
          isTrue,
          reason: 'sample_bdpm_compo.txt must exist at tool/data/',
        );

        final expectedFile = File('tool/data/expected_parsing_output.json');
        expect(
          await expectedFile.exists(),
          isTrue,
          reason: 'expected_parsing_output.json must exist at tool/data/',
        );

        final expectedJson =
            jsonDecode(
                  await expectedFile.readAsString(),
                )
                as Map<String, dynamic>;
        final expectedPrincipes = (expectedJson['principes'] as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList();

        final stream = sampleFile
            .openRead()
            .transform(latin1.decoder)
            .transform(const LineSplitter());

        final cisToCip13 = <String, List<String>>{
          '60002283': ['60002283'],
          '60004487': ['60004487'],
          '60004932': ['60004932'],
          '60009573': ['60009573'],
        };

        final resultEither = await BdpmFileParser.parseCompositions(
          stream,
          cisToCip13,
        );

        final result = resultEither.fold(
          ifLeft: (ParseError error) =>
              fail('Expected success but got error: $error'),
          ifRight: (List<PrincipeRow> value) => value,
        );

        expect(
          result.length,
          equals(expectedPrincipes.length),
          reason: 'Number of parsed principes should match expected',
        );

        for (var i = 0; i < expectedPrincipes.length; i++) {
          final expected = expectedPrincipes[i];
          final actual = result[i];

          expect(
            actual.codeCip,
            equals(expected['code_cip'] as String),
            reason: 'CIP code should match for principe $i',
          );
          expect(
            actual.principe,
            equals(expected['principe'] as String),
            reason: 'Principe name should match for principe $i',
          );
          expect(
            actual.dosage,
            equals(expected['dosage'] as String),
            reason: 'Dosage should match for principe $i',
          );
          expect(
            actual.dosageUnit,
            equals(expected['dosage_unit'] as String),
            reason: 'Dosage unit should match for principe $i',
          );
        }
      },
    );
  });
}
