import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/utils/gs1_parser.dart';

void main() {
  group('Gs1Parser', () {
    test('Parses GS1 DataMatrix correctly with basic AIs', () {
      const raw = '01034009340567811725123110BATCH123';
      final result = Gs1Parser.parse(raw);

      expect(result.gtin, '3400934056781');
      expect(result.expDate, DateTime.utc(2025, 12, 31));
      expect(result.lot, 'BATCH123');
      expect(result.manufacturingDate, isNull);
    });

    test('Parses GS1 with manufacturing date', () {
      const raw = '010340093405678111240115';
      final result = Gs1Parser.parse(raw);
      
      expect(result.gtin, '3400934056781');
      expect(result.manufacturingDate, DateTime.utc(2024, 1, 15));
    });

    test('Handles null and empty input', () {
      final result1 = Gs1Parser.parse(null);
      final result2 = Gs1Parser.parse('');
      
      expect(result1.gtin, isNull);
      expect(result1.serial, isNull);
      expect(result1.lot, isNull);
      expect(result1.expDate, isNull);
      expect(result1.manufacturingDate, isNull);
      
      expect(result2.gtin, isNull);
      expect(result2.serial, isNull);
      expect(result2.lot, isNull);
      expect(result2.expDate, isNull);
      expect(result2.manufacturingDate, isNull);
    });

    test('Handles incomplete data', () {
      const raw = '0103400934056781';
      final result = Gs1Parser.parse(raw);
      
      expect(result.gtin, '3400934056781');
      expect(result.expDate, isNull);
      expect(result.lot, isNull);
      expect(result.serial, isNull);
    });

    test('Handles data with separators', () {
      const raw = '0103400934056781\x1D17251231\x1D10BATCH123';
      final result = Gs1Parser.parse(raw);

      expect(result.gtin, '3400934056781');
      expect(result.expDate, DateTime.utc(2025, 12, 31));
      expect(result.lot, 'BATCH123');
    });
  });
}