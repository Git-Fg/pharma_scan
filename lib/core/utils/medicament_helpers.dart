// lib/core/utils/medicament_helpers.dart

import 'dart:convert';
import 'package:diacritic/diacritic.dart';
import 'package:pharma_scan/core/constants/dosage_constants.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/utils/strings.dart';

String findCommonPrincepsName(List<String> names) {
  if (names.isEmpty) return 'N/A';

  if (names.length == 1) return names.first;

  // Split the first name into words to create the initial prefix
  final List<String> prefixWords = names.first.split(' ');

  // Compare with other names to shorten the prefix
  for (int i = 1; i < names.length; i++) {
    final currentWords = names[i].split(' ');
    int commonLength = 0;
    while (commonLength < prefixWords.length &&
        commonLength < currentWords.length &&
        prefixWords[commonLength] == currentWords[commonLength]) {
      commonLength++;
    }

    // Shrink the prefix to the new common length
    if (commonLength < prefixWords.length) {
      prefixWords.removeRange(commonLength, prefixWords.length);
    }
  }

  if (prefixWords.isEmpty) {
    // Fallback to the shortest name if no common prefix is found
    return names.reduce((a, b) => a.length < b.length ? a : b);
  }

  // Join the words and clean up trailing characters like commas or dots
  return prefixWords.join(' ').trim().replaceAll(RegExp(r'[,.]\s*$'), '');
}

// WHY: Derive a concise display title from an already cleaned medication name by
// trimming trailing dosage information. This keeps UI titles deterministic and
// consistent with BDPM naming conventions.
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
  } catch (_) {
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
  return sanitized.join(', ');
}

String formatCommonPrincipes(String? rawJson) {
  final principles = decodePrincipesFromJson(rawJson);
  return formatCommonPrincipesFromList(principles);
}

/// WHY: Extract a clean princeps label from BDPM group labels.
/// - For generic group labels (format: "Generic - Brand"), we want the Brand part.
/// - Otherwise we just trim and return the raw label.
String extractPrincepsLabel(String rawLabel) {
  final trimmed = rawLabel.trim();
  if (trimmed.isEmpty) return trimmed;

  // Step 1: Group Split - BDPM convention "Generic - Brand"
  if (trimmed.contains(' - ')) {
    final parts = trimmed.split(' - ');
    return parts.last.trim();
  }

  // Fallback to trimmed label when there is no group separator
  return trimmed;
}

// WHY: Derive a concise display title from an already cleaned medication name by
// trimming trailing dosage information. Handles combination products (e.g., "A 50 + B 20")
// by processing each segment separately before rejoining, ensuring all molecules are preserved.
String deriveGroupTitleFromName(String name) {
  // Check if this is a combination product (contains " + " separator)
  if (name.contains(' + ')) {
    // Split into segments (e.g., ["ATENOLOL 50 mg", "NIFEDIPINE 20 mg"])
    final segments = name.split(' + ');

    // Process each segment individually to remove dosage
    final cleanedSegments = segments
        .map((segment) {
          return _deriveSingleMoleculeName(segment.trim());
        })
        .where((cleaned) => cleaned.isNotEmpty)
        .toList();

    // Rejoin with " + " separator
    return cleanedSegments.join(' + ');
  }

  // For mono-products, use the existing logic
  return _deriveSingleMoleculeName(name);
}

// WHY: Helper function to derive name from a single molecule segment.
// Stops at the first numeric value (dosage) and returns the molecule name.
String _deriveSingleMoleculeName(String name) {
  final parts = name.split(' ');
  final stopIndex = parts.indexWhere(
    (part) => double.tryParse(part.replaceAll(',', '.')) != null,
  );

  if (stopIndex != -1) {
    return parts
        .sublist(0, stopIndex)
        .join(' ')
        .replaceAll(RegExp(r'\s*,$'), '');
  }

  // Fallback for names without a clear dosage number
  return name.split(',').first.trim();
}

// WHY: Derive a clean display title from MedicamentSummaryData based on medication type.
// For generics in groups, splits the canonical name to remove princeps reference.
// For princeps (grouped or standalone), uses the princepsDeReference parsed via extractPrincepsLabel.
// For standalone non-princeps (theoretical), uses the already-cleaned canonical name.
String getDisplayTitle(MedicamentSummaryData summary) {
  // Any princeps (grouped or standalone): use princepsDeReference via shared parser
  if (summary.isPrinceps) {
    return extractPrincepsLabel(summary.princepsDeReference);
  }

  // Generic in group: split nomCanonique by " - " and take first part
  if (!summary.isPrinceps && summary.groupId != null) {
    final parts = summary.nomCanonique.split(' - ');
    return parts.first.trim();
  }

  // Standalone non-princeps fallback: use nomCanonique (already cleaned)
  return summary.nomCanonique;
}

// WHY: Sanitize active principle names by removing dosage, units, formulation keywords,
// and parenthetical content. This ensures clean display of active ingredient lists.
// Raw denomination_substance from BDPM can contain contaminated strings like
// "ESOMEPRAZOLE MAGNESIUM TRIHYDRATE équivalant à ESOMEPRAZOLE 40 mg".
// This logic ensures deterministic, contamination-free results for active principle names.
// Pre-compiled Regex patterns for sanitizeActivePrinciple
final _regexParentheses = RegExp(r'\s*\([^)]*\)');
final _regexEquivalent = RegExp(r'équivalant à', caseSensitive: false);
// WHY: Regex patterns for dosage units used in sanitization.
// Simple inline patterns matching common dosage units (mg, g, ml, UI, %, etc.).
final _regexDosageUnits = [
  RegExp(r'\b\d+([.,]\d+)?\s*mg\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*g\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*ml\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*mL\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*µg\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*mcg\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*ui\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*UI\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*U\.I\.\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*M\.U\.I\.\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*%', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*meq\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*mol\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*gbq\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*mbq\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*CH\b', caseSensitive: false), // Homéopathie
  RegExp(r'\b\d+([.,]\d+)?\s*DH\b', caseSensitive: false), // Homéopathie
];
final _regexUnitSlash = RegExp(r'\s*/[A-Z]+', caseSensitive: false);
final _regexTrailingSlash = RegExp(r'\s*/\s*', caseSensitive: false);
final _regexWhitespace = RegExp(r'\s+');
final _regexStandaloneNumber = RegExp(r'\b(\d+([.,]\d+)?)\b');
final _regexSpaceLetter = RegExp(r'^\s+[a-zA-Z]', caseSensitive: false);
final _regexDeFollows = RegExp(r'^de\b', caseSensitive: false);

// WHY: Sanitize active principle names by removing dosage, units, formulation keywords,
// and parenthetical content. This ensures clean display of active ingredient lists.
// Raw denomination_substance from BDPM can contain contaminated strings like
// "ESOMEPRAZOLE MAGNESIUM TRIHYDRATE équivalant à ESOMEPRAZOLE 40 mg".
// This logic ensures deterministic, contamination-free results for active principle names.
String sanitizeActivePrinciple(String principle) {
  if (principle.isEmpty) return principle;

  var sanitized = principle;

  // Step 1: Remove text in parentheses (often clarifications or salts)
  sanitized = sanitized.replaceAll(_regexParentheses, '');

  // Step 2: Remove text after "équivalant à" (case-insensitive)
  final equivalentMatch = _regexEquivalent.firstMatch(sanitized);
  if (equivalentMatch != null) {
    sanitized = sanitized.substring(0, equivalentMatch.start).trim();
  }

  // Step 3: Known molecules with numbers in their names (must preserve)
  // WHY: Use shared constant from DosageConstants to prevent logic drift between parser and sanitizer
  final knownNumberedMolecules = DosageConstants.knownNumberedMolecules;

  // Step 4: Remove dosage/unit patterns, but preserve known molecule numbers
  // First, handle known molecules that might appear with dosage units (e.g., "4000 UI/ML")
  for (final knownNumber in knownNumberedMolecules) {
    final numberUpper = knownNumber.toUpperCase();
    // Remove dosage units following known numbers (e.g., "4000 UI/ML" -> "4000")
    sanitized = sanitized.replaceAll(
      RegExp(
        r'\b' + RegExp.escape(knownNumber) + r'\s+(ui|UI)/?(ml|ML)\b',
        caseSensitive: false,
      ),
      knownNumber,
    );
    sanitized = sanitized.replaceAll(
      RegExp(
        r'\b' + RegExp.escape(numberUpper) + r'\s+(ui|UI)/?(ml|ML)\b',
        caseSensitive: false,
      ),
      knownNumber,
    );
  }

  // Step 5: Remove other dosage/unit patterns (e.g., "40 mg", "5 g", "0.5 %")
  for (final pattern in _regexDosageUnits) {
    sanitized = sanitized.replaceAll(pattern, '');
  }

  // Step 6: Remove remaining unit separators like "/ML" or "/ml" that may remain
  sanitized = sanitized.replaceAll(_regexUnitSlash, '');
  sanitized = sanitized.replaceAll(_regexTrailingSlash, '');

  // Step 7: Remove standalone numbers (except known molecule names and hyphenated numbers)
  // Normalize whitespace before processing
  sanitized = sanitized.trim().replaceAll(_regexWhitespace, ' ');

  sanitized = sanitized.replaceAllMapped(_regexStandaloneNumber, (match) {
    final number = match.group(1) ?? '';

    // Check if it's a known molecule name (check in context like Python does)
    final matchStart = match.start;
    final matchEnd = match.end;
    final snippetStart = matchStart > 2 ? matchStart - 2 : 0;
    final snippetEnd = matchEnd + 2 < sanitized.length
        ? matchEnd + 2
        : sanitized.length;
    final snippetUpper = sanitized
        .substring(snippetStart, snippetEnd)
        .toUpperCase();

    final isKnownMolecule = knownNumberedMolecules.any(
      (known) => snippetUpper.contains(known.toUpperCase()),
    );

    if (isKnownMolecule) {
      return number; // Keep the number if it's a known molecule
    }

    // Check if number is preceded by hyphen (likely part of molecule name)
    if (matchStart > 0 && sanitized[matchStart - 1] == '-') {
      return number; // Keep if preceded by hyphen
    }

    // Check if number is followed by space + letter (likely dosage, remove it)
    // This matches the Dart auditor pattern for detecting dosage numbers
    if (matchEnd < sanitized.length) {
      final afterNumber = sanitized.substring(matchEnd);
      if (_regexSpaceLetter.hasMatch(afterNumber)) {
        return ''; // Remove if followed by space + letter
      }
    }

    return ''; // Remove standalone numbers
  });

  // Normalize whitespace after number removal
  sanitized = sanitized.trim().replaceAll(_regexWhitespace, ' ');

  // Step 8: Remove formulation keywords (as whole words to avoid false positives)
  // This matches the Dart auditor approach: check exceptions per keyword, not globally
  final formulationKeywords = {
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
  };

  // Process each keyword with its specific exception pattern
  // Use a pattern that captures spaces around the keyword for proper removal
  for (final keyword in formulationKeywords) {
    // Pattern: (start or space) + keyword + (space or end)
    // This allows us to remove the keyword and its trailing space, but preserve leading space if needed
    final keywordPattern = RegExp(
      '(^|\\s)${RegExp.escape(keyword)}(\\s|\$)',
      caseSensitive: false,
    );

    sanitized = sanitized.replaceAllMapped(keywordPattern, (match) {
      // Check exception for this specific keyword (like the Dart auditor does per keyword)
      if (keyword == 'solution') {
        // Exception: "solution de" should be preserved
        // The pattern matches " solution " so we need to check what comes after
        final matchEnd = match.end;
        if (matchEnd < sanitized.length) {
          final afterMatch = sanitized.substring(matchEnd);
          // Check if "de" follows (the pattern already consumed the trailing space)
          if (_regexDeFollows.hasMatch(afterMatch)) {
            return match.group(0) ??
                ''; // Preserve "solution " in "solution de"
          }
        }
      }
      // Remove the keyword and its trailing space, but preserve leading space if it exists
      final prefix = match.group(1) ?? '';
      return prefix == ' '
          ? ' '
          : ''; // Keep space if keyword was preceded by space
    });
  }

  // Final trim and normalize whitespace
  return sanitized.trim().replaceAll(_regexWhitespace, ' ');
}

// WHY: Parse the main titulaire (laboratory) name from potentially multi-laboratory
// strings. The titulaire column can contain multiple laboratory names separated
// by semicolons or slashes. This function returns the first non-empty part.
String parseMainTitulaire(String? rawTitulaire) {
  if (rawTitulaire == null || rawTitulaire.isEmpty) {
    return Strings.unknownLab;
  }

  // Split by common delimiters (semicolon, slash)
  final parts = rawTitulaire.split(RegExp(r'[;/]'));

  // Find first non-empty part
  for (final part in parts) {
    final trimmed = part.trim();
    if (trimmed.isNotEmpty) {
      // Remove legal entity suffixes for cleaner matching
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

  // Fallback if all parts were empty
  return Strings.unknownLab;
}

// WHY: Clean standalone medication name by subtracting official form and lab.
// Uses official BDPM data (forme_pharmaceutique, titulaire) instead of heuristic parsing.
// Returns cleaned name with form and lab removed, or original name if subtraction fails.
String cleanStandaloneName({
  required String rawName,
  String? officialForm,
  String? officialLab,
}) {
  if (rawName.isEmpty) return rawName;

  var cleaned = rawName;

  if (officialForm != null && officialForm.trim().isNotEmpty) {
    cleaned = _removeOfficialForm(cleaned, officialForm);
  }

  if (officialLab != null && officialLab.trim().isNotEmpty) {
    final mainLab = parseMainTitulaire(officialLab);
    if (mainLab.isNotEmpty && mainLab != Strings.unknownLab) {
      cleaned = _removeNormalizedSubstring(cleaned, mainLab) ?? cleaned;
    }
  }

  cleaned = _finalizeStandaloneName(cleaned);

  if (cleaned.isEmpty || cleaned.length < 3) {
    return rawName;
  }

  return cleaned;
}

String _finalizeStandaloneName(String input) {
  var value = input
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s+,'), ',')
      .replaceAll(RegExp(r',\s+'), ', ')
      .replaceAll(RegExp(r'(,\s*){2,}'), ',')
      .trim();

  value = value.replaceAll(RegExp(r'^,+'), '').replaceAll(RegExp(r',+$'), '');

  // Remove dangling commas or connectors left after subtraction.
  value = value.replaceAll(RegExp(r'\s+,', caseSensitive: false), ', ');
  value = _stripTrailingPrepositions(value).trim();

  return value;
}

String _stripTrailingPrepositions(String input) {
  var value = input.trim();
  final trailingPattern = RegExp(
    r"(?:,?\s*)(?:pour|de|du|des|d'|\u00E0|au|aux)$",
    caseSensitive: false,
  );

  while (trailingPattern.hasMatch(value)) {
    value = value.replaceFirst(trailingPattern, '').trim();
  }

  return value;
}

String _removeOfficialForm(String source, String officialForm) {
  final variants = _buildFormVariants(officialForm);
  if (variants.isEmpty) return source;

  var updated = source;
  for (final variant in variants) {
    while (true) {
      final next = _removeNormalizedSubstring(updated, variant);
      if (next == null) break;
      updated = next;
    }
    if (updated != source) {
      break;
    }
  }

  return updated;
}

List<String> _buildFormVariants(String officialForm) {
  final normalized = _normalizeNeedle(officialForm);
  if (normalized.isEmpty) return const [];

  final parts = normalized.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final variants = <String>{normalized};
  final partsList = parts.toList();

  if (partsList.length > 1) {
    for (int len = partsList.length - 1; len >= 1; len--) {
      final candidate = partsList.take(len).join(' ');
      if (candidate.length > 2) {
        variants.add(candidate);
      }
    }
  }

  // Ensure the root noun (first word) is available as last resort.
  if (partsList.isNotEmpty) {
    variants.add(partsList.first);
  }

  final ordered = variants.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return ordered;
}

String _normalizeNeedle(String value) {
  return removeDiacritics(value).toLowerCase().trim();
}

String? _removeNormalizedSubstring(String source, String rawNeedle) {
  final normalizedNeedle = _normalizeNeedle(rawNeedle);
  if (normalizedNeedle.isEmpty) return null;

  final normalizedSource = removeDiacritics(source).toLowerCase();
  final start = normalizedSource.indexOf(normalizedNeedle);
  if (start == -1) return null;

  final end = start + normalizedNeedle.length;
  final startOriginal = _mapNormalizedBoundaryToOriginalIndex(source, start);
  final endOriginal = _mapNormalizedBoundaryToOriginalIndex(source, end);

  if (startOriginal == null ||
      endOriginal == null ||
      startOriginal >= endOriginal) {
    return null;
  }

  final result = source.replaceRange(startOriginal, endOriginal, '');
  return result;
}

int? _mapNormalizedBoundaryToOriginalIndex(String source, int boundary) {
  if (boundary <= 0) {
    return 0;
  }

  int normalizedPos = 0;
  for (int i = 0; i < source.length; i++) {
    final normalizedChar = removeDiacritics(source[i]).toLowerCase();
    if (normalizedChar.isEmpty) continue;
    final length = normalizedChar.length;
    final nextPos = normalizedPos + length;

    if (boundary == normalizedPos) {
      return i;
    }
    if (boundary > normalizedPos && boundary < nextPos) {
      return i;
    }
    if (boundary == nextPos) {
      return i + 1;
    }

    normalizedPos = nextPos;
  }

  if (boundary == normalizedPos) {
    return source.length;
  }

  return null;
}
