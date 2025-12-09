import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/services/ingestion/schema/bdpm_parsers.dart';

class _TestParser with BdpmRowParser {}

void main() {
  final parser = _TestParser();

  group('BdpmRowParser.parseRow', () {
    test('returns null for empty or short lines', () {
      expect(
        parser.parseRow('   ', 3, (cols) => cols),
        isNull,
      );
      expect(
        parser.parseRow('a\tb', 3, (cols) => cols),
        isNull,
      );
    });

    test('trims columns and maps when valid', () {
      final result = parser.parseRow<({String a, String b})>(
        ' a \t b \t c ',
        3,
        (cols) => (a: cols[0], b: cols[1]),
      );
      expect(result, isNotNull);
      expect(result!.a, 'a');
      expect(result.b, 'b');
    });

    test('returns null when mapper throws', () {
      final result = parser.parseRow(
        'a\tb\tc',
        3,
        (_) => throw Exception('boom'),
      );
      expect(result, isNull);
    });
  });

  group('BdpmRowParser value helpers', () {
    test('parseDouble handles commas and spaces', () {
      expect(parser.parseDouble('1 234,50'), 1234.5);
      expect(parser.parseDouble(''), isNull);
    });

    test('parseBool is oui-case-insensitive', () {
      expect(parser.parseBool('oui'), isTrue);
      expect(parser.parseBool('Oui'), isTrue);
      expect(parser.parseBool('non'), isFalse);
    });

    test('parseDate respects dd/MM/yyyy', () {
      final date = parser.parseDate('01/02/2024');
      expect(date?.year, 2024);
      expect(date?.month, 2);
      expect(date?.day, 1);
      expect(parser.parseDate(''), isNull);
    });
  });
}
