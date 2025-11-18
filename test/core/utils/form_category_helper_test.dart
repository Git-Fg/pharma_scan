import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/utils/form_category_helper.dart';
import 'package:pharma_scan/features/explorer/models/explorer_enums.dart';

void main() {
  group('FormCategoryHelper', () {
    test('returns configured keywords and exclusions for oral category', () {
      final result = FormCategoryHelper.getKeywordsForCategory(
        FormCategory.oral,
      );

      expect(result.formKeywords, containsAll(['comprimé', 'gélule']));
      expect(result.excludeKeywords, containsAll(['buvable', 'solution']));
    });

    test('returns aggregated exclusions when selecting other category', () {
      final result = FormCategoryHelper.getKeywordsForCategory(
        FormCategory.other,
      );

      expect(result.formKeywords, isEmpty);
      expect(result.excludeKeywords, contains('comprimé'));
      expect(result.excludeKeywords, contains('sirop'));
      expect(result.excludeKeywords, contains('spray nasal'));
    });
  });
}
