/// Mobile Thin Client Sanitizer
///
/// Implements the "Dumb Client, Smart Index" strategy.
/// All search normalization happens in the backend pipeline (search_vector)
/// and SQLite FTS5's trigram tokenizer. The mobile app passes raw input directly.
class Sanitizer {
  Sanitizer._();

  /// Pass-through normalizer for FTS5 trigram queries.
  ///
  /// SQLite FTS5 with `tokenize='trigram'` handles:
  /// - Fuzzy matching (e.g., "dolipprane" matches "doliprane")
  /// - Case insensitivity
  /// - Partial matches
  ///
  /// We only trim to avoid SQL syntax errors with empty/whitespace strings.
  static String normalizeForSearch(String input) {
    return input.trim();
  }
}
