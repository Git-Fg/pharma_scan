import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/logic/classifier.dart';
import 'package:pharma_scan/features/explorer/models/explorer_enums.dart';

void main() {
  group('Form classifier logic', () {
    test('returns configured keywords and exclusions for oral category', () {
      final result = keywordsForCategory(FormCategory.oral);

      expect(result.formKeywords, containsAll(['comprimé', 'gélule']));
      expect(result.excludeKeywords, containsAll(['buvable', 'solution']));
    });

    test('returns aggregated exclusions when selecting other category', () {
      final result = keywordsForCategory(FormCategory.other);

      expect(result.formKeywords, isEmpty);
      expect(result.excludeKeywords, contains('comprimé'));
      expect(result.excludeKeywords, contains('sirop'));
      expect(result.excludeKeywords, contains('spray nasal'));
    });

    group('getCategoryForForm - ATC-first logic', () {
      test(
        'S01 ATC code returns ophthalmic even with ambiguous form string',
        () {
          final result = classifyForm(
            'solution pour injection',
            atcCode: 'S01AA01',
          );

          expect(result, FormCategory.ophthalmic);
        },
      );

      test('D ATC code returns externalUse', () {
        final result = classifyForm('crème', atcCode: 'D07AC01');

        expect(result, FormCategory.externalUse);
      });

      test('G01 ATC code returns gynecological', () {
        final result = classifyForm('ovule', atcCode: 'G01AA10');

        expect(result, FormCategory.gynecological);
      });

      test('S02 ATC code returns nasalOrl', () {
        final result = classifyForm('spray nasal', atcCode: 'S02AA01');

        expect(result, FormCategory.nasalOrl);
      });

      test('R01 ATC code returns nasalOrl', () {
        final result = classifyForm('gouttes nasales', atcCode: 'R01AA01');

        expect(result, FormCategory.nasalOrl);
      });

      test(
        'items without ATC codes still categorize via regex (regression)',
        () {
          final result = classifyForm('comprimé', atcCode: null);

          expect(result, FormCategory.oral);
        },
      );

      test('invalid ATC codes fall back to regex', () {
        final result = classifyForm('comprimé', atcCode: 'X99XX99');

        expect(result, FormCategory.oral);
      });

      test('empty ATC code falls back to regex', () {
        final result = classifyForm('sirop', atcCode: '');

        expect(result, FormCategory.syrup);
      });

      test('ATC code takes precedence over ambiguous form string', () {
        // 'solution' could match multiple categories, but ATC code should win
        final result = classifyForm('solution', atcCode: 'S01AA01');

        expect(result, FormCategory.ophthalmic);
      });

      test('J01 ATC code returns oral (best-effort mapping)', () {
        // NOTE: J01 (anti-infectives) can be oral or injectable, but we map to oral
        // as a best-effort. The regex fallback will handle injectable forms.
        final result = classifyForm('comprimé', atcCode: 'J01AA01');

        expect(result, FormCategory.oral);
      });
    });
  });
}
