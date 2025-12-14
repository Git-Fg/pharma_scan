import 'package:diacritic/diacritic.dart';
import 'package:pharma_scan/core/utils/strings.dart';

/// Simple text utilities for cluster-first architecture
///
/// These functions are minimal since all complex sanitization occurs in the backend
/// and search vectors are pre-computed during pipeline processing.
String simpleNormalize(String input) {
  // Just for matching the format uppercase/sans accent of the backend
  return removeDiacritics(input).toUpperCase().trim();
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