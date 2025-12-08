import 'package:enough_convert/enough_convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';

void main() {
  group('Windows1252 decoding', () {
    test('decodes ligatures and euro sign', () {
      const codec = Windows1252Codec(allowInvalid: true);
      final decoded = codec.decode(const <int>[
        0x43,
        0x9C,
        0x75,
        0x72,
        0x20,
        0x80,
      ]);

      expect(decoded, contains('Cœur'));
      expect(decoded, contains('€'));
      expect(decoded.contains('�'), isFalse);
    });
  });

  group('Sanitizer normalization', () {
    test('normalizes œ/Œ for search', () {
      const input = '  Œdème Cœur  ';
      final normalized = normalizeForSearch(input);

      expect(normalized, equals('oedeme coeur'));
    });

    test('replaces punctuation with spaces for trigram safety', () {
      const input = ' ESTRO-FEM: "Base". ';
      final normalized = normalizeForSearch(input);

      expect(normalized, equals('estro fem base'));
    });

    test('normalizes œ/Œ for search index', () {
      const input = 'Cœur';
      final normalized = normalizeForSearchIndex(input);

      expect(normalized, equals('COEUR'));
    });
  });
}
