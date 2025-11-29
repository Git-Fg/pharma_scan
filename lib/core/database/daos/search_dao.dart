// lib/core/database/daos/search_dao.dart
import 'package:dart_either/dart_either.dart';
import 'package:diacritic/diacritic.dart';
import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/errors/failures.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';

part 'search_dao.g.dart';

String _escapeFts5Query(String query) {
  final normalized = removeDiacritics(query.trim()).toLowerCase();
  if (normalized.isEmpty) return '';

  final escaped = normalized
      .replaceAll('"', ' ')
      .replaceAll(':', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (escaped.isEmpty) return '';

  final terms = escaped.split(' ').where((t) => t.isNotEmpty).toList();
  if (terms.isEmpty) return '';

  return terms.join(' AND ');
}

@DriftAccessor(tables: [MedicamentSummary, Medicaments])
class SearchDao extends DatabaseAccessor<AppDatabase> with _$SearchDaoMixin {
  SearchDao(super.attachedDatabase);

  ({String sql, List<Variable<Object>> variables}) _buildSearchQuery(
    String sanitizedQuery,
    SearchFilters? filters,
  ) {
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

    final sql =
        '''
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

  Future<Either<Failure, List<MedicamentSummaryData>>> searchMedicaments(
    String query, {
    SearchFilters? filters,
  }) {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[SearchDao] Error in searchMedicaments for query: $query',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        final sanitizedQuery = _escapeFts5Query(query);
        if (sanitizedQuery.isEmpty) {
          LoggerService.db('Empty search query, returning empty results');
          return <MedicamentSummaryData>[];
        }

        LoggerService.db(
          'Searching medicaments with FTS5 query: $sanitizedQuery',
        );

        final queryData = _buildSearchQuery(sanitizedQuery, filters);

        final results = await db
            .customSelect(
              queryData.sql,
              variables: queryData.variables,
              readsFrom: {db.medicamentSummary},
            )
            .asyncMap((row) => db.medicamentSummary.mapFromRow(row))
            .get();

        return results;
      },
    );
  }

  Stream<Either<Failure, List<MedicamentSummaryData>>> watchMedicaments(
    String query, {
    SearchFilters? filters,
  }) {
    try {
      final sanitizedQuery = _escapeFts5Query(query);
      if (sanitizedQuery.isEmpty) {
        LoggerService.db('Empty search query, emitting empty stream');
        return Stream<Either<Failure, List<MedicamentSummaryData>>>.value(
          const Either.right(<MedicamentSummaryData>[]),
        );
      }

      LoggerService.db('Watching medicament search for query: $sanitizedQuery');

      final queryData = _buildSearchQuery(sanitizedQuery, filters);

      return db
          .customSelect(
            queryData.sql,
            variables: queryData.variables,
            readsFrom: {db.medicamentSummary},
          )
          .asyncMap((row) => db.medicamentSummary.mapFromRow(row))
          .watch()
          .map(
            Either<Failure, List<MedicamentSummaryData>>.right,
          )
          .handleError(
            (Object e, StackTrace stackTrace) {
              LoggerService.error(
                '[SearchDao] Error in watchMedicaments for query: $query',
                e,
                stackTrace,
              );
              return Either<Failure, List<MedicamentSummaryData>>.left(
                DatabaseFailure(e.toString(), stackTrace),
              );
            },
          );
    } on Exception catch (e, stackTrace) {
      LoggerService.error(
        '[SearchDao] Error setting up watchMedicaments for query: $query',
        e,
        stackTrace,
      );
      return Stream<Either<Failure, List<MedicamentSummaryData>>>.value(
        Either<Failure, List<MedicamentSummaryData>>.left(
          DatabaseFailure(e.toString(), stackTrace),
        ),
      );
    }
  }
}
