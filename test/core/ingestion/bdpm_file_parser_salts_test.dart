import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

void main() {
  group('_normalizeSaltPrefix (via debugNormalizeSaltPrefix)', () {
    test('removes simple salt prefixes', () {
      expect(
        debugNormalizeSaltPrefix('CHLORHYDRATE DE METFORMINE'),
        'METFORMINE',
      );
      expect(
        debugNormalizeSaltPrefix("SULFATE D'ALUMINIUM"),
        'ALUMINIUM',
      );
    });

    test('handles recursive salt prefixes', () {
      // Even if plusieurs sels sont enchaînés, on doit finir sur la molécule.
      expect(
        debugNormalizeSaltPrefix(
          'CHLORHYDRATE DE MALÉATE DE ROPINIROLE',
        ),
        'ROPINIROLE',
      );
    });
  });

  group('_removeSaltSuffixes (via debugRemoveSaltSuffixes)', () {
    test('removes simple salt suffixes', () {
      expect(
        debugRemoveSaltSuffixes('PERINDOPRIL ERBUMINE'),
        'PERINDOPRIL',
      );
      expect(
        debugRemoveSaltSuffixes('ELTROMBOPAG OLAMINE'),
        'ELTROMBOPAG',
      );
    });

    test('removes hydrate-related suffixes', () {
      expect(
        debugRemoveSaltSuffixes('ENTÉCAVIR MONOHYDRATÉ'),
        'ENTÉCAVIR',
      );
      expect(
        debugRemoveSaltSuffixes(
          'COMPLEXE SODIQUE SACUBITRIL VALSARTAN HÉMIPENTAHYDRATÉ',
        ),
        'COMPLEXE SODIQUE SACUBITRIL VALSARTAN',
      );
    });
  });
}
