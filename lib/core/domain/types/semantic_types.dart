import '../../../core/logic/sanitizer.dart';

/// Semantic type for normalized search queries.
///
/// This Extension Type guarantees that any instance is normalized according to
/// the FTS5 index normalization strategy using the canonical sanitizer.
///
/// **Invariant Guarantee:** The factory constructor ensures normalization happens
/// once at construction using Sanitizer.normalizeForSearch(), eliminating
/// redundant normalization calls throughout the codebase.
///
/// **2025 Standard:** All search queries must use `NormalizedQuery` to ensure
/// consistent normalization. See `.cursor/rules/domain-modeling.mdc` for details.
///
/// **Thin Client Architecture:** This type delegates normalization to
/// Sanitizer.normalizeForSearch() to maintain perfect synchronization with
/// backend_pipeline/src/sanitizer.ts
extension type NormalizedQuery(String _value) implements String {
  /// Factory constructor that normalizes and creates a [NormalizedQuery].
  ///
  /// **Normalization:** Delegates to Sanitizer.normalizeForSearch() which:
  /// - Removes diacritics (accents)
  /// - Converts to lowercase
  /// - Replaces non-alphanumeric characters with spaces
  /// - Collapses multiple spaces
  /// - Trims whitespace
  ///
  /// This ensures perfect synchronization with backend FTS5 normalization.
  ///
  /// **Empty Input:** If the input is empty or only whitespace, returns an empty normalized query.
  factory NormalizedQuery.fromString(String input) {
    final normalized = Sanitizer.normalizeForSearch(input);
    return normalized as NormalizedQuery;
  }

  /// Converts the normalized query into an FTS5-compatible MATCH string.
  ///
  /// Strategy:
  /// - Split on spaces (already normalized by the extension type)
  /// - Quote each non-empty term
  /// - Join with ` AND ` so all terms must match
  ///
  /// Returns empty string for empty input.
  String toFtsQuery() {
    final s = _value.trim();
    if (s.isEmpty) return '';
    final parts = s.split(' ').where((t) => t.isNotEmpty).map((t) => '"$t"');
    return parts.join(' AND ');
  }
}
