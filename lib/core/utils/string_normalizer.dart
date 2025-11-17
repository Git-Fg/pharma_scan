// lib/core/utils/string_normalizer.dart

const Map<String, String> _diacritics = {
  'À': 'A',
  'Á': 'A',
  'Â': 'A',
  'Ã': 'A',
  'Ä': 'A',
  'Å': 'A',
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'È': 'E',
  'É': 'E',
  'Ê': 'E',
  'Ë': 'E',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'Ì': 'I',
  'Í': 'I',
  'Î': 'I',
  'Ï': 'I',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'Ò': 'O',
  'Ó': 'O',
  'Ô': 'O',
  'Õ': 'O',
  'Ö': 'O',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'Ù': 'U',
  'Ú': 'U',
  'Û': 'U',
  'Ü': 'U',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'Ý': 'Y',
  'ý': 'y',
  'ÿ': 'y',
  'Ç': 'C',
  'ç': 'c',
  'Ñ': 'N',
  'ñ': 'n',
};

// WHY: Normalize strings to a canonical form (lowercase, no accents) for use as
// aggregation keys. This ensures that variations like "URSODESO" and "URSODÉSO"
// are treated as the same key, preventing duplicate entries in grouped results.
String normalize(String input) {
  String normalized = input.toLowerCase();
  for (var entry in _diacritics.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized;
}
