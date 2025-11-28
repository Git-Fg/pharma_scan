// lib/core/database/daos/search_dao.dart
import 'package:diacritic/diacritic.dart';
import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/features/explorer/models/search_filters_model.dart';

part 'search_dao.g.dart';

// WHY: Escape special FTS5 characters and normalize query to match index content
// FTS5 trigram tokenizer with Dart-side normalization ensures consistent matching
// Query is normalized (lowercase + diacritic removal) to match normalized index data
String _escapeFts5Query(String query) {
  // WHY: Normalize query at the start to match index content
  // Index contains normalized (lowercase, diacritic-free) text, so queries must match
  final normalized = removeDiacritics(query.trim()).toLowerCase();
  if (normalized.isEmpty) return '';

  // WHY: Escape special FTS5 characters: ", :, AND, OR, NOT
  // Replace with spaces to prevent syntax errors while preserving search intent
  var escaped = normalized
      .replaceAll('"', ' ')
      .replaceAll(':', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (escaped.isEmpty) return '';

  // WHY: Split into terms and combine with AND
  // Trigram tokenizer enables powerful substring matching for fuzzy search
  final terms = escaped.split(' ').where((t) => t.isNotEmpty).toList();
  if (terms.isEmpty) return '';

  return terms.join(' AND ');
}

@DriftAccessor(tables: [MedicamentSummary, Medicaments])
class SearchDao extends DatabaseAccessor<AppDatabase> with _$SearchDaoMixin {
  SearchDao(super.db);

  // WHY: Build shared FTS5 search query with filter support
  // Extracted to eliminate duplication between searchMedicaments and watchMedicaments
  // Returns SQL string and variables for use in customSelect queries
  ({String sql, List<Variable<Object>> variables}) _buildSearchQuery(
    String sanitizedQuery,
    SearchFilters? filters,
  ) {
    // WHY: Build WHERE clause and variables for filters
    final routeFilter = filters?.voieAdministration;
    final atcFilter = filters?.atcClass?.code;

    final filterClauses = <String>[];
    if (routeFilter != null) {
      filterClauses.add('AND ms.voies_administration LIKE ?');
    }
    if (atcFilter != null) {
      filterClauses.add('AND ms.atc_code LIKE ?');
    }
    final filterClause = filterClauses.join(' ');

    final variables = <Variable<Object>>[Variable<String>(sanitizedQuery)];
    if (routeFilter != null) {
      variables.add(Variable<String>('%$routeFilter%'));
    }
    if (atcFilter != null) {
      variables.add(Variable<String>('$atcFilter%'));
    }

    // WHY: Use custom query to join FTS5 search_index with medicament_summary
    // Use BM25 ranking for relevance ordering - better than simple rank for molecule searches
    // BM25 gives higher scores to documents where query terms appear in multiple fields
    // This ensures molecule names in active_principles field rank well alongside brand names
    final sql = '''
      SELECT ms.*,
             bm25(search_index) AS rank
      FROM medicament_summary ms
      INNER JOIN search_index si ON ms.cis_code = si.cis_code
      WHERE search_index MATCH ? $filterClause
      ORDER BY rank ASC, ms.nom_canonique
      LIMIT 50
      ''';

    return (sql: sql, variables: variables);
  }

  // WHY: Search medicaments using FTS5 full-text search directly in SQLite
  // This eliminates memory-heavy client-side indexing and provides fast, native search
  // Returns MedicamentSummaryData rows that match the query, ordered by relevance (BM25 rank)
  // WHY: Optimized for approximate molecule name matching across both princeps and generics
  Future<List<MedicamentSummaryData>> searchMedicaments(
    String query, {
    SearchFilters? filters,
  }) async {
    final sanitizedQuery = _escapeFts5Query(query);
    if (sanitizedQuery.isEmpty) {
      LoggerService.db('Empty search query, returning empty results');
      return [];
    }

    LoggerService.db('Searching medicaments with FTS5 query: $sanitizedQuery');

    final queryData = _buildSearchQuery(sanitizedQuery, filters);

    // WHY: Map query rows to MedicamentSummaryData using the table's mapper
    // FIX: Use .asyncMap() on Selectable, then .get() to get List<MedicamentSummaryData>
    // The .asyncMap() handles Future-returning mapFromRow correctly
    return db
        .customSelect(
          queryData.sql,
          variables: queryData.variables,
          readsFrom: {db.medicamentSummary},
        )
        .asyncMap((row) => db.medicamentSummary.mapFromRow(row))
        .get();
  }

  Stream<List<MedicamentSummaryData>> watchMedicaments(
    String query, {
    SearchFilters? filters,
  }) {
    final sanitizedQuery = _escapeFts5Query(query);
    if (sanitizedQuery.isEmpty) {
      LoggerService.db('Empty search query, emitting empty stream');
      return Stream<List<MedicamentSummaryData>>.value(
        const <MedicamentSummaryData>[],
      );
    }

    LoggerService.db('Watching medicament search for query: $sanitizedQuery');

    final queryData = _buildSearchQuery(sanitizedQuery, filters);

    // WHY: Map query rows to MedicamentSummaryData using the table's mapper
    // FIX: Use .asyncMap() on Selectable to handle Future-returning mapFromRow
    return db
        .customSelect(
          queryData.sql,
          variables: queryData.variables,
          readsFrom: {db.medicamentSummary},
        )
        .asyncMap((row) => db.medicamentSummary.mapFromRow(row))
        .watch();
  }
}
