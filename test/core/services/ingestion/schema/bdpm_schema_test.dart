import 'package:pharma_scan/core/services/ingestion/schema/bdpm_parsers.dart';
import 'package:pharma_scan/core/services/ingestion/schema/bdpm_schema.dart';
import 'package:test/test.dart';

class _TestParser with BdpmRowParser {}

void main() {
  group('BdpmRowParser', () {
    final parser = _TestParser();

    test('splitLine validates column count', () {
      expect(parser.splitLine('a\tb', 3), isEmpty);
      expect(parser.splitLine('a\tb\tc', 3), ['a', 'b', 'c']);
    });

    test('parseDate handles FR format', () {
      expect(
        parser.parseDate('01/02/2024')?.toIso8601String(),
        '2024-02-01T00:00:00.000Z',
      );
      expect(parser.parseDate(''), isNull);
      expect(parser.parseDate('invalid'), isNull);
    });

    test('parseDouble normalizes comma and spaces', () {
      expect(parser.parseDouble('1 234,50'), 1234.5);
      expect(parser.parseDouble(''), isNull);
    });
  });

  group('BdpmSpecialiteRow', () {
    test('fromLine parses valid row', () {
      final row = BdpmSpecialiteRow.fromLine(
        '12345678\tDenom\tForme\tOrale\tStatut\tProc\tCom\t01/02/2020\tBDM\tAUTH\tHolder\tOui',
      );
      expect(row, isNotNull);
      expect(row!.cis, '12345678');
      expect(row.surveillanceRenforcee, isTrue);
      expect(row.dateAmm?.year, 2020);
    });

    test('fromLine rejects short line', () {
      expect(BdpmSpecialiteRow.fromLine('a\tb'), isNull);
    });
  });

  group('BdpmPresentationRow', () {
    test('fromLine parses and normalizes price', () {
      final row = BdpmPresentationRow.fromLine(
        '12345678\t00000\tLibelle\tStatutAdmin\tCommercialise\t01/02/2020\t3400123456789\tOui\t65%\t12,50\tIndications',
      );
      expect(row, isNotNull);
      expect(row!.prixEuro, 12.5);
      expect(row.indicationsRemb, 'Indications');
    });

    test('fromLine rejects invalid column count', () {
      expect(BdpmPresentationRow.fromLine('short'), isNull);
    });
  });

  group('BdpmCompositionRow', () {
    test('fromLine parses substance code', () {
      final row = BdpmCompositionRow.fromLine(
        '12345678\tElem\t123\tDenom\t500 mg\tREF\tFT\t1',
      );
      expect(row, isNotNull);
      expect(row!.codeSubstance, '123');
      expect(row.natureComposant, 'FT');
    });
  });
}
