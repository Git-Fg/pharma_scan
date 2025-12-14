import 'package:diacritic/diacritic.dart';

/// Mobile Thin Client Sanitizer
///
/// This file contains ONLY the essential normalization function required for
/// search query compatibility with the backend FTS5 index.
///
/// All business sanitization logic has been moved to the backend pipeline
/// to maintain perfect synchronization and enforce thin client architecture.
///
/// The mobile app trusts nom_canonique and search_vector fields from the DB.
class Sanitizer {
  Sanitizer._();

  /// "Universal" Search Normalizer for Trigram FTS5.
  ///
  /// This function MUST remain perfectly synchronized with
  /// backend_pipeline/src/sanitizer.ts::normalizeForSearch()
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
  /// @example
  /// normalizeForSearch("DOLIPRANE®") => "doliprane"
  /// normalizeForSearch("Paracétamol 500mg") => "paracetamol 500mg"
  /// normalizeForSearch("Amoxicilline/Acide clavulanique") => "amoxicilline acide clavulanique"
  static String normalizeForSearch(String input) {
    if (input.isEmpty) return "";

    return removeDiacritics(input)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), " ")  // Replace non-alphanumeric with space
        .replaceAll(RegExp(r'\s+'), " ")           // Collapse multiple spaces
        .trim();
  }
}