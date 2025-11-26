// lib/core/database/daos/search_dao.dart
import 'package:diacritic/diacritic.dart';
import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/features/explorer/models/search_filters_model.dart';

part 'search_dao.g.dart';

// WHY: Sanitize FTS5 query string to prevent syntax errors and enable approximate matching
// Escapes special FTS5 characters, normalizes diacritics, and enables prefix matching for molecules
String _sanitizeFts5Query(String query, {bool enablePrefixMatching = true}) {
  // WHY: Trim and normalize whitespace
  final trimmed = query.trim();
  if (trimmed.isEmpty) return '';

  // WHY: Normalize diacritics to match both "paracetamol" and "paracétamol"
  // This improves approximate matching for molecule names with accents
  final normalized = removeDiacritics(trimmed);

  // WHY: Escape special FTS5 characters: ", :, AND, OR, NOT
  // Keep * for prefix matching if enabled
  var escaped = normalized
      .replaceAll('"', ' ')
      .replaceAll(':', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (escaped.isEmpty) return '';

  // WHY: Split into terms and process each
  final terms = escaped.split(' ').where((t) => t.isNotEmpty).toList();
  if (terms.isEmpty) return '';

  // WHY: For approximate molecule matching, use OR operator to search across all fields
  // and add prefix matching (*) to the last term for partial word completion
  // This allows "paracet" to match "paracetamol" and searches both princeps and generics
  if (enablePrefixMatching && terms.length == 1) {
    // Single word: use prefix matching for approximate completion
    return '${terms.first}*';
  } else if (enablePrefixMatching && terms.length > 1) {
    // Multi-word: use AND for all terms, but add prefix to last term for approximate matching
    final allButLast = terms.sublist(0, terms.length - 1);
    final lastTerm = '${terms.last}*';
    return '${allButLast.join(' AND ')} AND $lastTerm';
  } else {
    // No prefix matching: use AND for strict matching
    return terms.join(' AND ');
  }
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
    final sanitizedQuery = _sanitizeFts5Query(
      query,
      enablePrefixMatching: true,
    );
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
    return Future.wait(rows.map((row) => db.medicamentSummary.mapFromRow(row)));
  }
}
