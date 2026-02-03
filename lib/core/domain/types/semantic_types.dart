/// Semantic type for normalized search queries.
///
/// Implements "Dumb Client, Smart Index" strategy.
/// The database's FTS5 trigram tokenizer handles all fuzzy matching.
/// This type only provides basic input validation and FTS query formatting.
extension type NormalizedQuery(String _value) implements String {
  /// Factory constructor - pass through with trim only.
  ///
  /// SQLite FTS5 with `tokenize='trigram'` handles:
  /// - Fuzzy matching (typos like "dolipprane" → "doliprane")
  /// - Case-insensitive matching
  /// - Accent variations
  ///
  /// No client-side normalization needed.
  factory NormalizedQuery.fromString(String input) {
    // No normalization logic, just structure
    return NormalizedQuery(input.trim());
  }

  // Wraps in quotes to treat as a phrase for trigram matching
  // This helps find "Clamoxyl" within "Clamoxyl 500mg"
  String toFtsQuery() => '"$_value"';
}
