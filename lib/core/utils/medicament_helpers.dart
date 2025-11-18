// lib/core/utils/medicament_helpers.dart

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
String deriveGroupTitleFromName(String name) {
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

// WHY: Sanitize active principle names by removing dosage, units, formulation keywords,
// and parenthetical content. This ensures clean display of active ingredient lists.
// Raw denomination_substance from BDPM can contain contaminated strings like
// "ESOMEPRAZOLE MAGNESIUM TRIHYDRATE équivalant à ESOMEPRAZOLE 40 mg".
// This logic is harmonized with the Python auditor in data_validator.py to ensure
// deterministic, contamination-free results.
// Pre-compiled Regex patterns for sanitizeActivePrinciple
final _regexParentheses = RegExp(r'\s*\([^)]*\)');
final _regexEquivalent = RegExp(r'équivalant à', caseSensitive: false);
final _regexDosageUnits = [
  RegExp(r'\b\d+([.,]\d+)?\s*mg\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*g\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*ml\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*ui\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*%', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*ch\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*dh\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*gbq\b', caseSensitive: false),
  RegExp(r'\b\d+([.,]\d+)?\s*mbq\b', caseSensitive: false),
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
// This logic is harmonized with the Python auditor in data_validator.py to ensure
// deterministic, contamination-free results.
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
  final knownNumberedMolecules = {
    '4000',
    '3350',
    '980',
    '940',
    '6000',
    '2,4',
    '2.4',
  };

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
    // This matches Python's pattern: rf'\b{re.escape(number_token)}\s+[a-zA-Z]'
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
  // This matches Python's approach: check exceptions per keyword, not globally
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
      // Check exception for this specific keyword (like Python does per keyword)
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
    return 'Laboratoire Inconnu';
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
  return 'Laboratoire Inconnu';
}
