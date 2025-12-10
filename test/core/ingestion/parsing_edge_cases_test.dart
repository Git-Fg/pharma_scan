import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/services/ingestion/schema/bdpm_parsers.dart';

void main() {
  group('BdpmRowParser.parseDecimal', () {
    test('parses regular French decimals', () {
      final value = parseBdpmDecimal('1 234,56');
      expect(value, Decimal.parse('1234.56'));
    });

    test('ignores non-breaking spaces and control chars without throwing', () {
      const hostile = '12\u00a0345,67\u0000';
      expect(() => parseBdpmDecimal(hostile), returnsNormally);
      expect(parseBdpmDecimal(hostile), isNull);
    });

    test('handles extremely long junk strings safely', () {
      final longJunk = List.filled(2000, '\u0007').join();
      expect(() => parseBdpmDecimal(longJunk), returnsNormally);
      expect(parseBdpmDecimal(longJunk), isNull);
    });
  });

  group('BdpmRowParser.parseDate', () {
    test('parses valid DD/MM/YYYY dates', () {
      final date = parseBdpmDate('05/08/2023');
      expect(date, DateTime.utc(2023, 8, 5));
    });

    test(
      'returns null for dates with non-breaking spaces instead of crashing',
      () {
        const hostile = '05\u00a008\u00a02023';
        expect(() => parseBdpmDate(hostile), returnsNormally);
        expect(parseBdpmDate(hostile), isNull);
      },
    );

    test('is resilient to null bytes and control characters', () {
      const noisy = '05/08/2023\u0000';
      expect(() => parseBdpmDate(noisy), returnsNormally);
      expect(parseBdpmDate(noisy), isNull);
    });

    test('returns null for oversized inputs without throwing', () {
      final huge = List.filled(1024, 'x').join();
      expect(() => parseBdpmDate(huge), returnsNormally);
      expect(parseBdpmDate(huge), isNull);
    });
  });
}
