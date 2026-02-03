import 'package:pharma_scan/core/utils/strings.dart';

/// Simple text utilities for cluster-first architecture
///
/// Implements "Dumb Client, Smart Index" strategy.
/// The backend pipeline builds search vectors with all normalization.
/// SQLite FTS5 trigram tokenizer handles fuzzy matching at query time.
String simpleNormalize(String input) {
  return input.trim();
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
