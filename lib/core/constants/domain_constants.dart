// lib/core/constants/domain_constants.dart

import 'package:pharma_scan/features/explorer/models/explorer_enums.dart';

/// Centralized repository for static medical domain knowledge.
/// Contains ATC mappings, pharmaceutical form keywords, and classification rules.
class DomainConstants {
  const DomainConstants._();

  /// Maps ATC Level 1 & 3 prefixes to internal [FormCategory] values.
  /// Used for O(1) deterministic categorization.
  static const Map<String, FormCategory> atcPrefixMap = {
    'S01': FormCategory.ophthalmic,
    'S02': FormCategory.nasalOrl,
    'R01': FormCategory.nasalOrl,
    'D': FormCategory.externalUse,
    'G01': FormCategory.gynecological,
    'J01': FormCategory.oral,
  };

  /// Priority order for evaluating form categories.
  /// Specific forms (injectable) must be checked before general forms (oral).
  static const List<FormCategory> formPriorityOrder = [
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

  /// Keywords used to identify categories via substring matching when ATC is missing.
  static const Map<FormCategory, List<String>> formKeywords = {
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

  /// Terms that explicitly disqualify a match for a category.
  static const Map<FormCategory, List<String>> formExclusions = {
    FormCategory.oral: ['buvable', 'solution', 'suspension'],
    FormCategory.sachet: ['injectable', 'injection', 'parentéral', 'solvant'],
    FormCategory.externalUse: ['vaginal', 'vaginale'],
  };
}
