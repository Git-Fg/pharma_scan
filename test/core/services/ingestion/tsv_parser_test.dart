import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/services/ingestion/schema/bdpm_parsers.dart';

void main() {
  group('BDPM parsing helpers', () {
    test('parseDouble handles commas and spaces', () {
      expect(parseBdpmDouble('1 234,50'), 1234.5);
      expect(parseBdpmDouble(''), isNull);
    });

    test('parseBool is oui-case-insensitive', () {
      expect(parseBdpmBool('oui'), isTrue);
      expect(parseBdpmBool('Oui'), isTrue);
      expect(parseBdpmBool('non'), isFalse);
    });

    test('parseDate respects dd/MM/yyyy', () {
      final date = parseBdpmDate('01/02/2024');
      expect(date?.year, 2024);
      expect(date?.month, 2);
      expect(date?.day, 1);
      expect(parseBdpmDate(''), isNull);
    });
  });
}
