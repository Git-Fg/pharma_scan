import 'package:diacritic/diacritic.dart';

/// Semantic type for normalized search queries.
///
/// This Extension Type guarantees that any instance is normalized according to
/// the FTS5 index normalization strategy (linguistic normalization only).
///
/// **Invariant Guarantee:** The factory constructor ensures normalization happens
/// once at construction, eliminating redundant normalization calls throughout the codebase.
///
/// **2025 Standard:** All search queries must use `NormalizedQuery` to ensure
/// consistent normalization. See `.cursor/rules/flutter-architecture.mdc` for details.
///
/// **Normalization Strategy:** Uses linguistic normalization only (removeDiacritics + lowercase + trim)
/// to align with the FTS5 `normalize_text` SQL function. This preserves salts (e.g., "Chlorhydrate")
/// unlike `normalizePrincipleOptimal` which strips them.
extension type NormalizedQuery(String _value) implements String {
  /// Factory constructor that normalizes and creates a [NormalizedQuery].
  ///
  /// **Normalization:** Performs linguistic normalization only:
  /// - Removes diacritics (accents)
  /// - Converts to lowercase
  /// - Trims whitespace
  ///
  /// This aligns with the FTS5 `normalize_text` SQL function behavior, ensuring
  /// queries match indexed content. Salts and other pharmaceutical terms are preserved.
  ///
  /// **Empty Input:** If the input is empty or only whitespace, returns an empty normalized query.
  factory NormalizedQuery.fromString(String input) {
    if (input.trim().isEmpty) {
      return '' as NormalizedQuery;
    }
    final normalized = removeDiacritics(
      input,
    ).toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized as NormalizedQuery;
  }
}
