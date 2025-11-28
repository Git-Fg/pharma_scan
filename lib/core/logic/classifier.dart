// lib/core/logic/classifier.dart

import 'package:pharma_scan/core/constants/domain_constants.dart';
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

/// Determines the [FormCategory] for a given pharmaceutical form string using
/// ATC-first logic with keyword fallbacks. Returns `null` when no match exists.
FormCategory? classifyForm(String? formPharmaceutique, {String? atcCode}) {
  if (atcCode != null && atcCode.isNotEmpty) {
    if (atcCode.length >= 3) {
      final prefix = atcCode.substring(0, 3);
      if (DomainConstants.atcPrefixMap.containsKey(prefix)) {
        return DomainConstants.atcPrefixMap[prefix];
      }
    }
    final letter = atcCode.substring(0, 1);
    if (DomainConstants.atcPrefixMap.containsKey(letter)) {
      return DomainConstants.atcPrefixMap[letter];
    }
  }

  if (formPharmaceutique == null || formPharmaceutique.isEmpty) {
    return null;
  }

  final formLower = formPharmaceutique.toLowerCase().split(' ').join(' ');

  for (final category in DomainConstants.formPriorityOrder) {
    final keywords = DomainConstants.formKeywords[category] ?? const [];
    final exclusions = DomainConstants.formExclusions[category] ?? const [];

    final hasKeywordMatch = keywords.any(
      (keyword) => formLower.contains(keyword.toLowerCase()),
    );

    if (hasKeywordMatch) {
      final hasExclusionMatch = exclusions.any(
        (exclusion) => formLower.contains(exclusion.toLowerCase()),
      );

      if (!hasExclusionMatch) {
        return category;
      }
    }
  }

  return null;
}

FormCategoryKeywords keywordsForCategory(
  FormCategory category,
) => switch (category) {
  FormCategory.other => () {
    final excludedKeywords = <String>{};
    for (final cat in FormCategory.values) {
      if (cat != FormCategory.other) {
        excludedKeywords.addAll(DomainConstants.formKeywords[cat] ?? const []);
      }
    }
    return FormCategoryKeywords(
      formKeywords: const [],
      excludeKeywords: excludedKeywords.toList(),
    );
  }(),
  FormCategory.homeopathy => FormCategoryKeywords(
    formKeywords:
        DomainConstants.formKeywords[FormCategory.homeopathy] ?? const [],
    excludeKeywords:
        DomainConstants.formExclusions[FormCategory.homeopathy] ?? const [],
  ),
  FormCategory.phytotherapy => FormCategoryKeywords(
    formKeywords:
        DomainConstants.formKeywords[FormCategory.phytotherapy] ?? const [],
    excludeKeywords:
        DomainConstants.formExclusions[FormCategory.phytotherapy] ?? const [],
  ),
  _ => FormCategoryKeywords(
    formKeywords: DomainConstants.formKeywords[category] ?? const [],
    excludeKeywords: DomainConstants.formExclusions[category] ?? const [],
  ),
};
