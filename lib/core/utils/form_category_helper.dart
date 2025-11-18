// lib/core/utils/form_category_helper.dart
import 'package:pharma_scan/features/explorer/models/explorer_enums.dart';

class FormCategoryKeywords {
  const FormCategoryKeywords({
    required this.formKeywords,
    required this.excludeKeywords,
    this.procedureTypeKeywords = const [],
  });

  final List<String> formKeywords;
  final List<String> excludeKeywords;
  final List<String> procedureTypeKeywords;
}

class FormCategoryHelper {
  static final Map<FormCategory, List<String>> _keywords = {
    FormCategory.oral: [
      'comprimé',
      'gélule',
      'capsule',
      'lyophilisat',
      'comprimé orodispersible',
      'film orodispersible',
      'gomme',
      'gomme à mâcher',
      'pastille',
      'pastille à sucer',
      'plante pour tisane',
      'plantes pour tisane',
      'plante(s) pour tisane',
      'mélange de plantes pour tisane',
      'plante en vrac',
    ],
    FormCategory.syrup: ['sirop', 'suspension buvable'],
    FormCategory.drinkableDrops: [
      'solution buvable',
      'gouttes buvables',
      'solution en gouttes',
      'solution gouttes',
    ],
    FormCategory.sachet: [
      'sachet',
      'poudre pour solution buvable',
      'poudre pour suspension buvable',
      'granulé',
      'granules',
      'granulés',
      'poudre',
    ],
    FormCategory.injectable: [
      'injectable',
      'injection',
      'perfusion',
      'solution pour perfusion',
      'poudre pour solution injectable',
      'solution pour injection',
      'dispersion pour perfusion',
      'usage parentéral',
      'parentéral',
      'poudre et solvant',
      'générateur radiopharmaceutique',
      'précurseur radiopharmaceutique',
      'solution pour dialyse',
      'solution pour hémofiltration',
      'solution pour instillation',
      'solution cardioplégique',
      'solution pour administration intravésicale',
      'suspension pour instillation',
    ],
    FormCategory.gynecological: [
      'ovule',
      'pessaire',
      'comprimé vaginal',
      'crème vaginale',
      'gel vaginal',
      'capsule vaginale',
      'tampon vaginal',
      'anneau vaginal',
    ],
    FormCategory.externalUse: [
      'crème',
      'pommade',
      'gel',
      'lotion',
      'pâte',
      'cutanée',
      'cutané',
      'application locale',
      'application cutanée',
      'dispositif transdermique',
      'patch',
      'patchs',
      'emplâtre',
      'compresse',
      'bâton pour application',
      'mousse pour application',
      'mousse',
      'pansement',
      'implant',
      'shampooing',
      'solution filmogène pour application',
      'dispositif pour application',
      'solution pour application',
      'solution moussant',
      'solution pour lavage',
      'suppositoire',
    ],
    FormCategory.ophthalmic: [
      'collyre',
      'ophtalmique',
      'solution ophtalmique',
      'pommade ophtalmique',
      'gel ophtalmique',
      'solution pour irrigation oculaire',
    ],
    FormCategory.nasalOrl: [
      'nasale',
      'auriculaire',
      'buccale',
      'aérosol',
      'spray nasal',
      'gouttes nasales',
      'gouttes auriculaires',
      'bain de bouche',
      'collutoire',
      'gaz pour inhalation',
      'gaz',
      'cartouche pour inhalation',
      'dispersion pour inhalation',
      'inhalation',
      'insert',
      'solution pour pulvérisation',
    ],
    FormCategory.other: [],
  };

  static final Map<FormCategory, List<String>> _exclusions = {
    FormCategory.oral: ['buvable', 'solution', 'suspension'],
    FormCategory.sachet: ['injectable', 'injection', 'parentéral', 'solvant'],
    FormCategory.externalUse: ['vaginal', 'vaginale'],
  };

  // WHY: Priority-ordered list for deterministic form categorization.
  // More specific forms (injectable, gynecological) are checked before general forms (oral).
  // This ensures ambiguous forms like "solution pour injection" are correctly classified.
  static const List<FormCategory> _priorityOrder = [
    FormCategory.injectable,
    FormCategory.gynecological,
    FormCategory.ophthalmic,
    FormCategory.nasalOrl,
    FormCategory.externalUse,
    FormCategory.sachet,
    FormCategory.syrup,
    FormCategory.drinkableDrops,
    FormCategory.oral,
  ];

  // WHY: Determines the FormCategory for a given pharmaceutical form string
  // using priority-based matching. This makes categorization deterministic
  // and handles ambiguous forms correctly.
  static FormCategory? getCategoryForForm(String? formPharmaceutique) {
    if (formPharmaceutique == null || formPharmaceutique.isEmpty) {
      return null;
    }

    // Normalize multiple spaces to single space for matching
    final formLower = formPharmaceutique.toLowerCase().split(' ').join(' ');

    // Iterate through priority order, stop at first match
    for (final category in _priorityOrder) {
      final keywords = _keywords[category] ?? const [];
      final exclusions = _exclusions[category] ?? const [];

      // Check if any keyword matches
      final hasKeywordMatch = keywords.any(
        (keyword) => formLower.contains(keyword.toLowerCase()),
      );

      if (hasKeywordMatch) {
        // Check if any exclusion matches
        final hasExclusionMatch = exclusions.any(
          (exclusion) => formLower.contains(exclusion.toLowerCase()),
        );

        // If keyword matches and no exclusion matches, assign this category
        if (!hasExclusionMatch) {
          return category;
        }
      }
    }

    // No match found
    return null;
  }

  static FormCategoryKeywords getKeywordsForCategory(FormCategory category) {
    if (category == FormCategory.homeopathy) {
      return const FormCategoryKeywords(
        formKeywords: [],
        excludeKeywords: [],
        procedureTypeKeywords: ['homéo'],
      );
    }

    if (category == FormCategory.phytotherapy) {
      return const FormCategoryKeywords(
        formKeywords: [],
        excludeKeywords: [],
        procedureTypeKeywords: ['phyto'],
      );
    }

    if (category == FormCategory.other) {
      final allOtherKeywords = <String>{};
      for (final cat in FormCategory.values) {
        if (cat != FormCategory.other &&
            cat != FormCategory.homeopathy &&
            cat != FormCategory.phytotherapy) {
          allOtherKeywords.addAll(_keywords[cat] ?? []);
        }
      }
      return FormCategoryKeywords(
        formKeywords: const [],
        excludeKeywords: allOtherKeywords.toList(),
      );
    }

    return FormCategoryKeywords(
      formKeywords: _keywords[category] ?? const [],
      excludeKeywords: _exclusions[category] ?? const [],
    );
  }
}
