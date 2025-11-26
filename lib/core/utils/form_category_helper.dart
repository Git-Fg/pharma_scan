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
  // WHY: ATC code mapping for O(1) categorization lookup
  // Maps ATC code prefixes to FormCategory for fast, deterministic categorization
  // NOTE: J01 (anti-infectives) can be oral or injectable, so this is a best-effort mapping.
  // The regex fallback will handle edge cases where form string indicates injectable.
  static const Map<String, FormCategory> _atcMap = {
    'S01': FormCategory.ophthalmic,
    'S02': FormCategory.nasalOrl,
    'R01': FormCategory.nasalOrl,
    'D': FormCategory.externalUse,
    'G01': FormCategory.gynecological,
    'J01': FormCategory.oral,
  };

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
      'trousse',
      'générateur',
      'précurseur',
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
      'vernis',
      'compresse',
      'bâton pour application',
      'mousse pour application',
      'mousse',
      'pansement',
      'implant',
      'shampooing',
      'solution filmogène pour application',
      'dispositif pour application',
      'dispositif',
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
    FormCategory.homeopathy: ['homéopathique', 'homeopathique'],
    FormCategory.phytotherapy: ['plante', 'plantes', 'tisane'],
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
    FormCategory.homeopathy,
    FormCategory.phytotherapy,
  ];

  // WHY: Determines the FormCategory for a given pharmaceutical form string
  // using ATC-first logic (O(1) lookup) with regex fallback. This makes categorization
  // deterministic and handles ambiguous forms correctly.
  //
  // USAGE: When categorizing a medication from MedicamentSummary, pass the atcCode:
  //   FormCategoryHelper.getCategoryForForm(
  //     summaryRow.formePharmaceutique,
  //     atcCode: summaryRow.atcCode,
  //   )
  // This enables O(1) ATC-based categorization when available, falling back to regex
  // for items without ATC codes.
  static FormCategory? getCategoryForForm(
    String? formPharmaceutique, {
    String? atcCode,
  }) {
    // ATC-first logic: Use ATC code as primary determinant if available
    if (atcCode != null && atcCode.isNotEmpty) {
      // Check 3-character prefix (e.g., 'S01')
      if (atcCode.length >= 3) {
        final prefix = atcCode.substring(0, 3);
        if (_atcMap.containsKey(prefix)) {
          return _atcMap[prefix];
        }
      }
      // Check 1-character prefix (e.g., 'D')
      final letter = atcCode.substring(0, 1);
      if (_atcMap.containsKey(letter)) {
        return _atcMap[letter];
      }
    }

    // Fallback to regex-based logic if ATC lookup fails or atcCode is null
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

  static FormCategoryKeywords getKeywordsForCategory(FormCategory category) =>
      switch (category) {
        FormCategory.other => () {
          final excludedKeywords = <String>{};
          for (final cat in FormCategory.values) {
            if (cat != FormCategory.other) {
              excludedKeywords.addAll(_keywords[cat] ?? []);
            }
          }
          return FormCategoryKeywords(
            formKeywords: const [],
            excludeKeywords: excludedKeywords.toList(),
          );
        }(),
        FormCategory.homeopathy => FormCategoryKeywords(
          formKeywords: _keywords[FormCategory.homeopathy] ?? const [],
          excludeKeywords: _exclusions[FormCategory.homeopathy] ?? const [],
        ),
        FormCategory.phytotherapy => FormCategoryKeywords(
          formKeywords: _keywords[FormCategory.phytotherapy] ?? const [],
          excludeKeywords: _exclusions[FormCategory.phytotherapy] ?? const [],
        ),
        _ => FormCategoryKeywords(
          formKeywords: _keywords[category] ?? const [],
          excludeKeywords: _exclusions[category] ?? const [],
        ),
      };
}
