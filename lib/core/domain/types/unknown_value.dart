/// Extension Type for handling potentially unknown string values
///
/// Provides type safety for values that might be "Unknown" or empty.
/// This eliminates the common pattern of checking `value.toUpperCase() != Strings.unknown.toUpperCase()`.
extension type UnknownAwareString(String _value) {
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
    if (normalized == 'unknown' ||
        normalized == 'inconnu' ||
        normalized == 'non spécifié' ||
        normalized == 'non renseigné' ||
        normalized == 'n/a' ||
        normalized == 'nd') {
      return UnknownAwareString.empty();
    }

    return UnknownAwareString(trimmed);
  }

  /// Creates an empty/unknown value
  const UnknownAwareString.empty() : _value = '';

  /// Creates a known value
  const UnknownAwareString.value(String value) : _value = value;

  /// Gets the raw string value
  String get value => _value;

  /// Checks if the value is empty/unknown
  bool get isEmpty => _value.isEmpty;

  /// Checks if the value has content (not empty/unknown)
  bool get hasContent => _value.isNotEmpty;

  /// Gets the display value (empty string shows as '-')
  String get displayValue => _value.isEmpty ? '-' : _value;

  /// Gets the value with a fallback
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