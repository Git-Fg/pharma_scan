import 'package:pharma_scan/core/services/ingestion/schema/bdpm_parsers.dart';
import 'package:test/test.dart';

void main() {
  group('Bdpm parsing helpers', () {
    test('parseDate handles FR format', () {
      expect(
        parseBdpmDate('01/02/2024')?.toIso8601String(),
        '2024-02-01T00:00:00.000Z',
      );
      expect(parseBdpmDate(''), isNull);
      expect(parseBdpmDate('invalid'), isNull);
    });

    test('parseDouble normalizes comma and spaces', () {
      expect(parseBdpmDouble('1 234,50'), 1234.5);
      expect(parseBdpmDouble(''), isNull);
    });
  });
}
