import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';

/// Tests for the "Universal" Search Normalizer.
///
/// These tests verify that [normalizeForSearch] implements the standard
/// linguistic normalization protocol that is replicated in the backend.
///
/// The normalization rules are:
/// 1. Remove Diacritics (é -> e, ï -> i, etc.)
/// 2. Lowercase (A -> a)
/// 3. Replace non-alphanumeric (except spaces) with space
/// 4. Collapse multiple spaces to single space
/// 5. Trim leading/trailing whitespace
void main() {
  group('normalizeForSearch - Universal Trigram FTS Normalization', () {
    group('Basic cases', () {
      test('empty string returns empty', () {
        expect(normalizeForSearch(''), equals(''));
      });

      test('simple lowercase', () {
        expect(normalizeForSearch('DOLIPRANE'), equals('doliprane'));
        expect(normalizeForSearch('Paracetamol'), equals('paracetamol'));
      });

      test('accents removed', () {
        expect(normalizeForSearch('Paracétamol'), equals('paracetamol'));
        expect(normalizeForSearch('ÉPHÉDRINE'), equals('ephedrine'));
        expect(normalizeForSearch('Caféine'), equals('cafeine'));
        expect(normalizeForSearch('Naïf'), equals('naif'));
        expect(normalizeForSearch('Façade'), equals('facade'));
      });

      test('numbers preserved', () {
        expect(normalizeForSearch('Doliprane 500'), equals('doliprane 500'));
        expect(
          normalizeForSearch('PARACETAMOL 1000MG'),
          equals('paracetamol 1000mg'),
        );
      });
    });

    group('Special characters replaced with space', () {
      test('punctuation replaced', () {
        expect(
          normalizeForSearch('anti-inflammatoire'),
          equals('anti inflammatoire'),
        );
        // ® is replaced with space, but trailing space is trimmed
        expect(normalizeForSearch('Doliprane®'), equals('doliprane'));
        expect(normalizeForSearch("L'aspirine"), equals('l aspirine'));
        expect(normalizeForSearch('test.dot'), equals('test dot'));
        expect(normalizeForSearch('test:colon'), equals('test colon'));
        expect(normalizeForSearch('test"quote'), equals('test quote'));
      });

      test('slashes replaced', () {
        expect(
          normalizeForSearch('Amoxicilline/Acide clavulanique'),
          equals('amoxicilline acide clavulanique'),
        );
      });

      test('parentheses replaced', () {
        expect(
          normalizeForSearch('Sodium (chlorure)'),
          equals('sodium chlorure'),
        );
      });
    });

    group('Whitespace handling', () {
      test('multiple spaces collapsed', () {
        expect(normalizeForSearch('hello   world'), equals('hello world'));
        expect(normalizeForSearch('  leading'), equals('leading'));
        expect(normalizeForSearch('trailing  '), equals('trailing'));
      });

      test('mixed special chars and spaces', () {
        expect(
          normalizeForSearch('test - with - dashes'),
          equals('test with dashes'),
        );
        expect(
          normalizeForSearch('test/with/slashes'),
          equals('test with slashes'),
        );
      });
    });

    group('Real-world medication names', () {
      test('Doliprane variants', () {
        expect(normalizeForSearch('DOLIPRANE®'), equals('doliprane'));
        expect(
          normalizeForSearch('DOLIPRANE 1000 mg, comprimé'),
          equals('doliprane 1000 mg comprime'),
        );
      });

      test('Amoxicilline with salts', () {
        expect(
          normalizeForSearch('AMOXICILLINE ACIDE CLAVULANIQUE'),
          equals('amoxicilline acide clavulanique'),
        );
        expect(
          normalizeForSearch('Amoxicilline (trihydraté)'),
          equals('amoxicilline trihydrate'),
        );
      });

      test('Complex names', () {
        expect(
          normalizeForSearch('IBUPROFÈNE LYSINE'),
          equals('ibuprofene lysine'),
        );
        expect(
          normalizeForSearch("PHOSPHATE DE CODÉINE HÉMIHYDRATÉ"),
          equals('phosphate de codeine hemihydrate'),
        );
      });
    });

    group('Edge cases for typo tolerance testing', () {
      // These test that the normalization is predictable and symmetric
      // so that typos in queries can still match via trigram similarity
      test('typos produce similar normalized forms', () {
        // "dolipprane" (common typo) normalizes cleanly
        expect(normalizeForSearch('dolipprane'), equals('dolipprane'));
        expect(normalizeForSearch('doliprane'), equals('doliprane'));

        // The trigram tokenizer will match these because they share many trigrams:
        // "dol", "oli", "lip", "pra", "ran", "ane" overlap between both

        // "amoxicylline" (common typo with y instead of i)
        expect(normalizeForSearch('amoxicylline'), equals('amoxicylline'));
        expect(normalizeForSearch('amoxicilline'), equals('amoxicilline'));
      });
    });
  });

  group('normalizeForSearchIndex - Chemical Name Normalization', () {
    // Note: normalizeForSearchIndex is the more complex normalization
    // used during indexing to clean up chemical names

    test('basic functionality', () {
      expect(
        normalizeForSearchIndex('PARACETAMOL'),
        equals('PARACETAMOL'),
      );
    });

    test('removes ACIDE prefix', () {
      expect(
        normalizeForSearchIndex('ACIDE ACETYLSALICYLIQUE'),
        equals('ACETYLSALICYLIQUE'),
      );
    });

    test('handles stereo-isomers', () {
      expect(
        normalizeForSearchIndex('( R ) - AMLODIPINE'),
        equals('AMLODIPINE'),
      );
      expect(
        normalizeForSearchIndex('( S ) - OMEPRAZOLE'),
        equals('OMEPRAZOLE'),
      );
    });
  });
}
