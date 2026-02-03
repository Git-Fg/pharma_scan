import '../../utils/strings.dart';

/// Extension Type for handling potentially unknown string values
///
/// Provides type safety for values that might be "Unknown" or empty.
/// This eliminates the common pattern of checking `value.toUpperCase() != Strings.unknown.toUpperCase()`.
extension type UnknownAwareString(String _value) implements String {
  /// Creates an UnknownAwareString from a raw database string
  ///
  /// Automatically detects unknown/empty values and normalizes them.
  factory UnknownAwareString.fromDatabase(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return UnknownAwareString.empty();
    }

    final trimmed = rawValue.trim();

    // Check for common "unknown" variations
    final normalized = trimmed.toLowerCase();

    // List of values considered as "unknown"
    const unknownSynonyms = [
      'unknown',
      'inconnu',
      'non spécifié',
      'non renseigné',
      'n/a',
      'nd',
      '-',
    ];

    // Also check against localized "Unknown" string
    if (unknownSynonyms.contains(normalized) ||
        normalized == Strings.unknown.toLowerCase()) {
      return UnknownAwareString.empty();
    }

    return UnknownAwareString(trimmed);
  }

  /// Creates an empty/unknown value
  const UnknownAwareString.empty() : _value = '';

  /// Creates a known value
  const UnknownAwareString.value(String value) : _value = value;

  String get value => _value;
  bool get isEmpty => _value.isEmpty;
  bool get hasContent => _value.isNotEmpty;
  String get displayValue => _value.isEmpty ? '-' : _value;
  String getWithFallback(String fallback) => _value.isEmpty ? fallback : _value;

  /// Compares two UnknownAwareString values for sorting
  int compareTo(UnknownAwareString other) {
    // Both empty - they're equal
    if (isEmpty && other.isEmpty) return 0;

    // Empty values come last
    if (isEmpty) return 1;
    if (other.isEmpty) return -1;

    // Compare case-insensitively
    return _value.toLowerCase().compareTo(other.value.toLowerCase());
  }

  /// Checks if the value contains the search term (case-insensitive)
  bool contains(String searchTerm, {bool caseSensitive = false}) {
    if (isEmpty || searchTerm.isEmpty) return false;

    final haystack = caseSensitive ? _value : _value.toLowerCase();
    final needle = caseSensitive ? searchTerm : searchTerm.toLowerCase();

    return haystack.contains(needle);
  }
}
