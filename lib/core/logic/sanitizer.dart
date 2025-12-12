import 'package:diacritic/diacritic.dart';
import 'package:pharma_scan/core/utils/strings.dart';

/// "Universal" Search Normalizer for Trigram FTS5.
///
/// This is the CANONICAL normalization function that MUST match exactly
/// the backend implementation (backend_pipeline/src/sanitizer.ts).
///
/// Rules:
/// 1. Remove Diacritics (é -> e, ï -> i, etc.)
/// 2. Lowercase (A -> a)
/// 3. Alphanumeric Only - replace [^a-z0-9\s] with space
/// 4. Collapse multiple spaces to single space
/// 5. Trim leading/trailing whitespace
///
/// WHY TRIGRAM: The FTS5 trigram tokenizer handles fuzzy matching natively
/// (e.g., "dolipprane" matches "doliprane"). We only need to normalize
/// the input to remove accents and ensure consistent casing.
///
/// Example:
/// ```dart
/// normalizeForSearch("DOLIPRANE®") // => "doliprane"
/// normalizeForSearch("Paracétamol 500mg") // => "paracetamol 500mg"
/// normalizeForSearch("Amoxicilline/Acide clavulanique") // => "amoxicilline acide clavulanique"
/// ```
String normalizeForSearch(String input) {
  if (input.isEmpty) return '';

  return removeDiacritics(input)
      .toLowerCase()
      .replaceAll(
        RegExp(r'[^a-z0-9\s]'),
        ' ',
      ) // Replace non-alphanumeric with space
      .replaceAll(RegExp(r'\s+'), ' ') // Collapse multiple spaces
      .trim();
}

/// Parses the main titulaire (laboratory name) from a raw titulaire string.
///
/// Extracts the first laboratory name from a semicolon/slash-separated list
/// and removes common company suffixes (SAS, SA, SARL, etc.) for display.
///
/// Example:
/// ```dart
/// parseMainTitulaire("LABORATOIRE XYZ SAS; AUTRE LAB") // => "LABORATOIRE XYZ"
/// parseMainTitulaire("COMPANY INC") // => "COMPANY"
/// ```
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
