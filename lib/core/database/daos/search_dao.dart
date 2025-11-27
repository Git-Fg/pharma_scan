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

    // WHY: Build WHERE clause and variables for filters
    final routeFilter = filters?.voieAdministration;
    final atcFilter = filters?.atcClass;

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
    final rows = await db
        .customSelect(
          '''
      SELECT ms.*,
             bm25(search_index) AS rank
      FROM medicament_summary ms
      INNER JOIN search_index si ON ms.cis_code = si.cis_code
      WHERE search_index MATCH ? $filterClause
      ORDER BY rank ASC, ms.nom_canonique
      LIMIT 50
      ''',
          variables: variables,
          readsFrom: {db.medicamentSummary},
        )
        .get();

    // WHY: Map query rows to MedicamentSummaryData using the table's mapper
    return Future.wait(rows.map(db.medicamentSummary.mapFromRow));
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

    final routeFilter = filters?.voieAdministration;
    final atcFilter = filters?.atcClass;

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

    final statement = db.customSelect(
      '''
      SELECT ms.*,
             bm25(search_index) AS rank
      FROM medicament_summary ms
      INNER JOIN search_index si ON ms.cis_code = si.cis_code
      WHERE search_index MATCH ? $filterClause
      ORDER BY rank ASC, ms.nom_canonique
      LIMIT 50
      ''',
      variables: variables,
      readsFrom: {db.medicamentSummary},
    );

    return statement.watch().asyncMap(
      (rows) => Future.wait(rows.map(db.medicamentSummary.mapFromRow)),
    );
  }
}
