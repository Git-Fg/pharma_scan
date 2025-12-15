import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/utils/gs1_parser.dart';

void main() {
  group('Complete GS1 DataMatrix Test', () {
    test('Test the complete code you provided', () {
      // The exact complete GS1 code from your example
      const completeGs1Code =
          '01034009303026132132780924334799\u001d10MA00614A\u001d17270430';

      final gs1Data = Gs1Parser.parse(completeGs1Code);

      // Test each expected field
      expect(gs1Data.gtin, '3400930302613',
          reason: 'CIP should be extracted correctly');
      expect(gs1Data.serial, '32780924334799',
          reason: 'Serial should be extracted correctly');
      expect(gs1Data.lot, 'MA00614A',
          reason: 'Lot should be extracted correctly');

      final expectedExpDate = DateTime.utc(2027, 4, 30);
      expect(gs1Data.expDate, expectedExpDate,
          reason: 'Exp date should be 2027-04-30');
    });
  });
}
