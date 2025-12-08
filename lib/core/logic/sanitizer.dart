import 'dart:convert';

import 'package:diacritic/diacritic.dart';
import 'package:pharma_scan/core/constants/chemical_constants.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';

/// Canonical normalization for search queries/columns.
String normalizeForSearch(String input) {
  if (input.isEmpty) return '';

  return removeDiacritics(input)
      .toLowerCase()
      .replaceAll(RegExp('[-\'":.]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> decodePrincipesFromJson(String? jsonString) {
  if (jsonString == null || jsonString.isEmpty) return const <String>[];
  try {
    final decoded = jsonDecode(jsonString);
    if (decoded is List) {
      return decoded
          .map((value) => (value?.toString() ?? '').trim())
          .where((value) => value.isNotEmpty)
          .cast<String>()
          .toList();
    }
    return const <String>[];
  } on Exception catch (_) {
    return const <String>[];
  }
}

String formatCommonPrincipesFromList(List<String>? principles) {
  if (principles == null || principles.isEmpty) return '';
  final sanitized = principles
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
  if (sanitized.isEmpty) return '';
  sanitized.sort();
  return sanitized.join(', ');
}

String formatCommonPrincipes(String? rawJson) {
  final principles = decodePrincipesFromJson(rawJson);
  return formatCommonPrincipesFromList(principles);
}

String extractPrincepsLabel(String rawLabel) {
  final trimmed = rawLabel.trim();
  if (trimmed.isEmpty) return trimmed;

  if (trimmed.contains(' - ')) {
    final parts = trimmed.split(' - ');
    return parts.last.trim();
  }

  return trimmed;
}

String getDisplayTitle(MedicamentEntity summary) {
  if (summary.data.isPrinceps) {
    return extractPrincepsLabel(summary.data.princepsDeReference);
  }

  if (!summary.data.isPrinceps && summary.groupId != null) {
    final parts = summary.data.nomCanonique.split(' - ');
    return parts.first.trim();
  }

  return summary.data.nomCanonique;
}

/// Detects pure electrolytes / mineral salts.
///
/// If the string consists solely of an inorganic salt + DE + mineral ion
/// (without other organic active principles), preserve the complete form
/// as the canonical molecule.
bool _isPureInorganicName(String name) {
  final tokens = name.split(' ').where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) return false;

  const mineralTokens = ChemicalConstants.mineralTokens;

  const inorganicCores = <String>{
    'CHLORURE',
    'PHOSPHATE',
    'CARBONATE',
    'BICARBONATE',
    'SULFATE',
    'NITRATE',
    'HYDROXYDE',
    'OXIDE',
  };

  const inorganicModifiers = <String>{
    'MONOPOTASSIQUE',
    'DIPOTASSIQUE',
    'MONOSODIQUE',
    'DISODIQUE',
  };

  if (tokens.length == 1 && mineralTokens.contains(tokens[0])) {
    return true;
  }

  // <core> DE <mineral>
  if (tokens.length == 3 &&
      inorganicCores.contains(tokens[0]) &&
      (tokens[1] == 'DE' || tokens[1] == "D'" || tokens[1] == "D'") &&
      mineralTokens.contains(tokens[2])) {
    return true;
  }

  // <core> <modifier> (ex: PHOSPHATE MONOPOTASSIQUE)
  if (tokens.length == 2 &&
      inorganicCores.contains(tokens[0]) &&
      inorganicModifiers.contains(tokens[1])) {
    return true;
  }

  return false;
}

/// Strictly reserved for FTS5 search index normalization.
/// Do NOT use for UI display strings or parsing heuristics.
@pragma('vm:prefer-inline')
String normalizeForSearchIndex(String principe) {
  if (principe.trim().isEmpty) return '';

  // Uppercase after diacritic removal to ensure ligatures like œ/Œ normalize
  // to their full ASCII equivalents (e.g., OE) instead of mixed-case outputs.
  var normalized = removeDiacritics(
    principe.toUpperCase().trim(),
  ).toUpperCase();

  normalized = normalized.replaceAll(RegExp(r'^ACIDE\s+'), '');
  final stereoMatch = RegExp(
    r'^\(\s*([RS])\s*\)\s*-\s*(.+)$',
  ).firstMatch(normalized);
  if (stereoMatch != null) {
    final core = stereoMatch.group(2)?.trim() ?? '';
    if (core.isNotEmpty) {
      normalized = core;
    }
  }

  final inverseMatch = RegExp(
    r'^([A-Z0-9\-]+)\s*\(\s*([^()]+?)\s+DE\s*\)$',
  ).firstMatch(normalized);
  if (inverseMatch != null) {
    final group1 = (inverseMatch.group(1) ?? '').trim();
    final group2 = (inverseMatch.group(2) ?? '').trim();

    const mineralElectrolytes = {
      'SODIUM',
      'POTASSIUM',
      'CALCIUM',
      'MAGNESIUM',
      'LITHIUM',
      'ZINC',
      'FER',
      'CUIVRE',
    };

    if (mineralElectrolytes.contains(group1)) {
      final inner = group2.replaceAll(RegExp(r"\s+(DE|D[''])\s*$"), '').trim();
      if (inner.isNotEmpty) {
        normalized = inner;
      }
    } else {
      normalized = group1;
    }
  }

  if (_isPureInorganicName(normalized)) {
    return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  const noisePrefixes = <String>[
    'SOLUTION DE',
    'CONCENTRAT DE',
  ];
  for (final prefix in noisePrefixes) {
    if (normalized.startsWith('$prefix ')) {
      normalized = normalized.substring(prefix.length).trimLeft();
    }
  }

  const noiseSuffixes = <String>[
    'FORME PULVERULENTE',
    'FORME PULVERULENTE,',
    'FORME PULVERULENTE .',
    'LIQUIDE',
  ];
  for (final suffix in noiseSuffixes) {
    final suffixEscaped = RegExp.escape(suffix);
    normalized = normalized
        .replaceAll(
          RegExp(r'\s*,?\s*' + suffixEscaped + r'$', caseSensitive: false),
          '',
        )
        .trim();
  }

  normalized = normalized.replaceFirst(RegExp(r'CONCENTRAT DE\s+'), '');
  normalized = normalized.replaceFirst(
    RegExp(r',\s*FORME PULV[EÉ]RULENTE\s*$'),
    '',
  );
  normalized = normalized.replaceFirst(RegExp(r'^SOLUTION DE\s+'), '');
  normalized = normalized.replaceFirst(RegExp(r',\s*SOLUTION DE\s*$'), '');
  normalized = normalized.replaceFirst(RegExp(r'\s+BETADEX-CLATHRATE\s*$'), '');
  normalized = normalized.replaceFirst(
    RegExp(r'\s+PROPYLENE GLYCOLATE\s*$'),
    '',
  );

  normalized = normalized.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '');

  var result = normalized;

  for (final prefix in ChemicalConstants.saltPrefixes) {
    if (result.startsWith(prefix)) {
      final rest = result.substring(prefix.length);
      if (prefix.endsWith("'")) {
        result = rest.trimLeft();
        break;
      }
      if (rest.isEmpty || rest.startsWith(' ')) {
        result = rest.trimLeft();
        break;
      }
    }
  }

  for (final mineral in ChemicalConstants.mineralTokens) {
    final mineralEscaped = RegExp.escape(mineral);
    final suffixPattern =
        r'\s+(DE\s+|D['
            '])' +
        mineralEscaped +
        r'$';
    result = result
        .replaceAll(
          RegExp(suffixPattern, caseSensitive: false),
          '',
        )
        .trim();

    final prefixPattern =
        '^$mineralEscaped'
        r'\s+(DE\s+|D['
        '])';
    result = result
        .replaceAll(
          RegExp(prefixPattern, caseSensitive: false),
          '',
        )
        .trim();
  }

  for (final suffix in ChemicalConstants.saltSuffixes) {
    if (result.endsWith(' $suffix')) {
      result = result
          .substring(0, result.length - suffix.length)
          .trimRight()
          .trim();
    }
  }

  result = result.replaceAll(
    RegExp(r'\s*\([A-Z]+\s+D[E\u0027\u2019].*\)$'),
    '',
  );

  for (final salt in ChemicalConstants.saltSuffixes) {
    final saltEscaped = RegExp.escape(salt);
    result = result.replaceAll(
      RegExp(r'\s*\(' + saltEscaped + r'\)'),
      '',
    );
  }

  if (result.contains('OMEGA-3') || result.contains('OMEGA 3')) {
    final omegaMatch = RegExp(
      'OMEGA[- ]?3',
      caseSensitive: false,
    ).firstMatch(result);
    if (omegaMatch != null) {
      result = omegaMatch.group(0)!.toUpperCase().replaceAll(' ', '-');
    }
  }

  if (result.contains('CALCITONINE')) {
    if (result.contains('SAUMON') ||
        result.contains('SALMINE') ||
        result.contains('SYNTHETIQUE')) {
      result = 'CALCITONINE';
    }
  }

  result = result.replaceAll(
    RegExp('CARBOCYSTEINE', caseSensitive: false),
    'CARBOCISTEINE',
  );
  result = result.replaceAll(
    RegExp('SEVORANE', caseSensitive: false),
    'SEVOFLURANE',
  );
  result = result.replaceAll(
    RegExp(r'^COLECALCIFEROL$', caseSensitive: false),
    'CHOLECALCIFEROL',
  );
  result = result.replaceAll(
    RegExp('CHOLÉCALCIFÉROL', caseSensitive: false),
    'CHOLECALCIFEROL',
  );
  result = result.replaceAll(
    RegExp('COLÉCALCIFÉROL', caseSensitive: false),
    'CHOLECALCIFEROL',
  );
  result = result.replaceAll(
    RegExp('URSODÉOXYCHOLIQUE', caseSensitive: false),
    'URSODEOXYCHOLIQUE',
  );
  result = result.replaceAll(
    RegExp('URSODÉSOXYCHOLIQUE', caseSensitive: false),
    'URSODEOXYCHOLIQUE',
  );
  result = result.replaceAll(
    RegExp('URSODESOXYCHOLIQUE', caseSensitive: false),
    'URSODEOXYCHOLIQUE',
  );
  result = result.replaceAll(
    RegExp('ISÉTIONATE', caseSensitive: false),
    'ISETHIONATE',
  );
  result = result.replaceAll(
    RegExp('ISÉTHIONATE', caseSensitive: false),
    'ISETHIONATE',
  );
  result = result.replaceAll(
    RegExp('DIISÉTHIONATE', caseSensitive: false),
    'DIISETHIONATE',
  );

  // CLAVULANATE / CLAVULANIQUE
  if (result.contains('CLAVULAN')) {
    result = result.replaceAll(
      RegExp('CLAVULANATE', caseSensitive: false),
      'CLAVULANIQUE',
    );
    result = result.replaceFirst(
      RegExp(r'\s+DE\s+POTASSIUM\s+DILUE\s*$'),
      '',
    );
    if (result.startsWith('CLAVULANIQUE')) {
      result = 'CLAVULANIQUE';
    }
  }

  // Variantes supplémentaires
  result = result.replaceAll(
    RegExp('CYAMEPROMAZINE', caseSensitive: false),
    'CYAMEMAZINE',
  );
  result = result.replaceAll(
    RegExp('REMIFENTANYL', caseSensitive: false),
    'REMIFENTANIL',
  );
  result = result.replaceAll(
    RegExp('VALPROIQUE', caseSensitive: false),
    'VALPROATE',
  );

  // TRYPTOPHANE
  if (result.contains('TRYPTOPHANE')) {
    result = result.replaceFirst(RegExp(r'\s+L\s*$'), '');
    if (result.startsWith('TRYPTOPHANE')) {
      result = 'TRYPTOPHANE';
    }
  }

  // ALCOOL DICHLOROBENZYLIQUE
  if (result.contains('DICHLORO') && result.contains('BENZYLIQUE')) {
    result = result.replaceAll(
      RegExp('DICHLORO-2,4', caseSensitive: false),
      'DICHLORO',
    );
    result = result.replaceAll(
      RegExp(r'DICHLORO\s+BENZYLIQUE', caseSensitive: false),
      'DICHLOROBENZYLIQUE',
    );
  }

  // PHOSPHATE MONOSODIQUE
  if (result == 'PHOSPHATE MONOSODIQUE') {
    result = 'PHOSPHATE';
  }

  for (final prefix in noisePrefixes) {
    if (result.startsWith('$prefix ')) {
      result = result.substring(prefix.length).trimLeft();
    }
  }

  for (final suffix in noiseSuffixes) {
    final suffixEscaped = RegExp.escape(suffix);
    result = result
        .replaceAll(
          RegExp(r'\s*,?\s*' + suffixEscaped + r'$', caseSensitive: false),
          '',
        )
        .trim();
  }

  result = result
      .replaceAll(
        RegExp(r'\(CONCENTRAT\s+DE\)', caseSensitive: false),
        '',
      )
      .trim();

  result = result.replaceAll(RegExp(r'[,\s]+$'), '').trim();

  return result.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String parseMainTitulaire(String? rawTitulaire) {
  if (rawTitulaire == null || rawTitulaire.isEmpty) {
    return Strings.unknownLab;
  }

  final parts = rawTitulaire.split(RegExp('[;/]'));

  for (final part in parts) {
    final trimmed = part.trim();
    if (trimmed.isNotEmpty) {
      final cleaned = trimmed
          .replaceAll(
            RegExp(r'\s+(SAS|SA|SARL|GMBH|LTD|INC)$', caseSensitive: false),
            '',
          )
          .trim();

      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }
  }

  return Strings.unknownLab;
}

/// Generates a grouping key by extracting the canonical base name and
/// applying aggressive normalization to remove dosages, units, and formatting.
///
/// This function is used to create consistent grouping keys for medications
/// that share the same molecule but have different dosages or formulations.
///
/// The function:
/// 1. Extracts the canonical base name (before " - ") if present
/// 2. Applies aggressive normalization to remove all dosage information
/// 3. Falls back to the normalized input if base extraction fails
///
/// Returns an uppercase normalized string suitable for grouping.
String generateGroupingKey(String input) {
  if (input.isEmpty) return input;

  String baseName;
  if (input.contains(' - ')) {
    baseName = input.split(' - ').first.trim();
  } else {
    baseName = input.trim();
  }

  var normalized = baseName;

  normalized = normalized.replaceAll(RegExp(r'\s*\([^)]*\)'), '');

  // Remove "équivalant à" / "équivalent à" and everything after
  final equivalentMatch = RegExp(
    'équivalant à|équivalent à',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (equivalentMatch != null) {
    normalized = normalized.substring(0, equivalentMatch.start).trim();
  }

  // Remove "pour" patterns BEFORE removing numbers
  normalized = normalized.replaceAll(
    RegExp(
      r'\s+\d+([.,]\d+)?\s*(mg|g|ml|mL|µg|mcg|ui|UI|%)\s+pour\s+\d+([.,]\d+)?\s*(mg|g|ml|mL|µg|mcg|ui|UI|%)\b',
      caseSensitive: false,
    ),
    '',
  );
  normalized = normalized.replaceAll(
    RegExp(
      r'\s+\d+([.,]\d+)?\s+pour\s+\d+([.,]\d+)?\s*(mg|g|ml|mL|µg|mcg|ui|UI|%)\b',
      caseSensitive: false,
    ),
    '',
  );
  normalized = normalized.replaceAll(
    RegExp(
      r'\s+pour\s+\d+([.,]\d+)?\s*(mg|g|ml|mL|µg|mcg|ui|UI|%)\b',
      caseSensitive: false,
    ),
    '',
  );
  normalized = normalized.replaceAll(
    RegExp(r'\s+pour\s+\d+([.,]\d+)?\b', caseSensitive: false),
    '',
  );
  normalized = normalized.replaceAll(
    RegExp(r'\s+pour\s*$', caseSensitive: false),
    '',
  );

  normalized = normalized.replaceAll(
    RegExp(
      r'\b\d+([.,]\d+)?\s+(mg|g|ml|mL|µg|mcg|ui|UI|U\.I\.|M\.U\.I\.|%|meq|mol|gbq|mbq|CH|DH|microgrammes?|milligrammes?)\b',
      caseSensitive: false,
    ),
    '',
  );
  normalized = normalized.replaceAll(
    RegExp(
      r'\b\d+([.,]\d+)?(mg|g|ml|mL|µg|mcg|ui|UI|U\.I\.|M\.U\.I\.|%|meq|mol|gbq|mbq|CH|DH)\b',
      caseSensitive: false,
    ),
    '',
  );

  normalized = normalized.replaceAll(RegExp(r'\b\d+([.,]\d+)?\b'), '');

  normalized = normalized.replaceAll(
    RegExp(r'\s*%\s*', caseSensitive: false),
    '',
  );
  normalized = normalized.replaceAll(
    RegExp(r'\s+POUR\s+CENT\b', caseSensitive: false),
    '',
  );
  normalized = normalized.replaceAll(
    RegExp(r'\s+POURCENT\b', caseSensitive: false),
    '',
  );

  normalized = normalized.replaceAll(
    RegExp(r'\s*/\s*\w+', caseSensitive: false),
    '',
  );
  normalized = normalized.replaceAll(RegExp(r'\s*/\s*'), '');

  const formulationKeywords = {
    'comprimé',
    'gélule',
    'solution',
    'injectable',
    'poudre',
    'sirop',
    'suspension',
    'crème',
    'pommade',
    'gel',
    'collyre',
    'inhalation',
    'orodispersible',
    'sublingual',
    'transdermique',
    'gingival',
    'pelliculé',
    'effervescent',
    'buvable',
  };
  for (final keyword in formulationKeywords) {
    final keywordPattern = RegExp(
      '(^|\\s)${RegExp.escape(keyword)}(\\s|\$)',
      caseSensitive: false,
    );
    normalized = normalized.replaceAll(keywordPattern, ' ');
  }

  normalized = normalized.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();

  if (normalized.isEmpty || normalized.length < 3) {
    final baseOnly = baseName
        .replaceAll(RegExp(r'\s+\d+.*$', caseSensitive: false), '')
        .trim();
    return baseOnly.isEmpty
        ? input.toUpperCase().trim()
        : baseOnly.toUpperCase().trim();
  }

  return normalized;
}

String normalizePrincipleOptimal(String principe) =>
    normalizeForSearchIndex(principe);
