import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/utils/gs1_parser.dart';

void main() {
  group('Gs1Parser', () {
    group('Basic parsing', () {
      test('parses GS1 DataMatrix correctly with basic AIs', () {
        const raw = '01034009340567811725123110BATCH123';
        final result = Gs1Parser.parse(raw);

        expect(result.gtin, '3400934056781');
        expect(result.expDate, DateTime.utc(2025, 12, 31));
        expect(result.lot, 'BATCH123');
        expect(result.manufacturingDate, isNull);
      });

      test('parses GS1 with manufacturing date', () {
        const raw = '010340093405678111240115';
        final result = Gs1Parser.parse(raw);

        expect(result.gtin, '3400934056781');
        expect(result.manufacturingDate, DateTime.utc(2024, 1, 15));
      });

      test('handles incomplete data (GTIN only)', () {
        const raw = '0103400934056781';
        final result = Gs1Parser.parse(raw);

        expect(result.gtin, '3400934056781');
        expect(result.expDate, isNull);
        expect(result.lot, isNull);
        expect(result.serial, isNull);
      });

      test('parses data with FNC1 separators', () {
        const raw = '0103400934056781\x1D17251231\x1D10BATCH123';
        final result = Gs1Parser.parse(raw);

        expect(result.gtin, '3400934056781');
        expect(result.expDate, DateTime.utc(2025, 12, 31));
        expect(result.lot, 'BATCH123');
      });
    });

    group('Null and empty input', () {
      test('handles null input', () {
        final result = Gs1Parser.parse(null);

        expect(result.gtin, isNull);
        expect(result.serial, isNull);
        expect(result.lot, isNull);
        expect(result.expDate, isNull);
        expect(result.manufacturingDate, isNull);
      });

      test('handles empty input', () {
        final result = Gs1Parser.parse('');

        expect(result.gtin, isNull);
        expect(result.serial, isNull);
        expect(result.lot, isNull);
        expect(result.expDate, isNull);
        expect(result.manufacturingDate, isNull);
      });
    });

    group('Edge cases', () {
      test('parses serial number (AI 21)', () {
        const raw = '0103400934056781\x1D21SERIAL001';
        final result = Gs1Parser.parse(raw);

        expect(result.gtin, '3400934056781');
        expect(result.serial, 'SERIAL001');
      });

      test('parses all fields together', () {
        const raw = '01034009340567811725123110LOT001\x1D21SER001';
        final result = Gs1Parser.parse(raw);

        expect(result.gtin, '3400934056781');
        expect(result.expDate, DateTime.utc(2025, 12, 31));
        expect(result.lot, 'LOT001');
        expect(result.serial, 'SER001');
      });

      test('handles multiple consecutive FNC1 separators', () {
        const raw = '0103400934056781\x1D\x1D\x1D10BATCH';
        final result = Gs1Parser.parse(raw);

        expect(result.gtin, '3400934056781');
        expect(result.lot, 'BATCH');
      });

      test('handles variable-length fields with special characters', () {
        const raw = '0103400934056781\x1D10ABC-123/XY';
        final result = Gs1Parser.parse(raw);

        expect(result.gtin, '3400934056781');
        expect(result.lot, 'ABC-123/XY');
      });

      test('handles unusual AI ordering (expiry before GTIN)', () {
        // Real-world barcodes may have AIs in any order
        const raw = '17251231\x1D0103400934056781';
        final result = Gs1Parser.parse(raw);

        expect(result.gtin, '3400934056781');
        expect(result.expDate, DateTime.utc(2025, 12, 31));
      });

      test('handles empty variable-length fields', () {
        const raw = '0103400934056781\x1D10\x1D21';
        final result = Gs1Parser.parse(raw);

        expect(result.gtin, '3400934056781');
        // Empty lot and serial should be null or empty
        expect(result.lot, anyOf(isNull, isEmpty));
        expect(result.serial, anyOf(isNull, isEmpty));
      });

      test('handles whitespace as FNC1 equivalent', () {
        const raw = '0103400934056781 10BATCH123';
        final result = Gs1Parser.parse(raw);

        expect(result.gtin, '3400934056781');
        expect(result.lot, 'BATCH123');
      });
    });

    group('Date parsing', () {
      test('handles day 00 (end of month)', () {
        const raw = '0103400934056781\x1D17250200'; // Feb 00 = end of Feb
        final result = Gs1Parser.parse(raw);

        expect(
            result.expDate, DateTime.utc(2025, 2, 28)); // 2025 is not leap year
      });

      test('handles leap year day 00', () {
        const raw = '0103400934056781\x1D17240200'; // Feb 00, 2024
        final result = Gs1Parser.parse(raw);

        expect(result.expDate, DateTime.utc(2024, 2, 29)); // 2024 is leap year
      });

      test('handles Y2K pivot (year 49 -> 2049)', () {
        const raw = '0103400934056781\x1D17490115';
        final result = Gs1Parser.parse(raw);

        expect(result.expDate, DateTime.utc(2049, 1, 15));
      });

      test('handles Y2K pivot (year 50 -> 1950)', () {
        const raw = '0103400934056781\x1D17500115';
        final result = Gs1Parser.parse(raw);

        expect(result.expDate, DateTime.utc(1950, 1, 15));
      });
    });

    group('Invalid input handling', () {
      test('handles completely malformed input gracefully', () {
        const raw = 'INVALID_BARCODE_DATA';
        final result = Gs1Parser.parse(raw);

        // Should not crash, just return empty
        expect(result.gtin, isNull);
      });

      test('handles truncated GTIN (less than 14 digits)', () {
        const raw = '01340093'; // Only 6 digits after AI
        final result = Gs1Parser.parse(raw);

        // Parser should handle gracefully
        expect(result.gtin, isNull);
      });

      test('handles invalid date values', () {
        const raw = '0103400934056781\x1D17991399'; // Month 13 is invalid
        final result = Gs1Parser.parse(raw);

        expect(result.gtin, '3400934056781');
        expect(result.expDate, isNull); // Invalid date should be null
      });
    });
  });
}
