// lib/core/database/daos/library_dao.dart

import 'package:dart_either/dart_either.dart';
import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/errors/failures.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';

part 'library_dao.g.dart';

@DriftAccessor(
  tables: [
    MedicamentSummary,
    Specialites,
    Medicaments,
    GroupMembers,
    GeneriqueGroups,
    PrincipesActifs,
  ],
)
class LibraryDao extends DatabaseAccessor<AppDatabase> with _$LibraryDaoMixin {
  LibraryDao(super.attachedDatabase);

  Stream<Either<Failure, List<ViewGroupDetail>>> watchGroupDetails(
    String groupId,
  ) {
    try {
      LoggerService.db('Watching group $groupId via view_group_details');
      final view = attachedDatabase.viewGroupDetails;
      final query = select(view)
        ..where((tbl) => tbl.groupId.equals(groupId))
        ..orderBy([
          (tbl) =>
              OrderingTerm(expression: tbl.isPrinceps, mode: OrderingMode.desc),
          (tbl) => OrderingTerm.asc(tbl.nomCanonique),
        ]);
      return query
          .watch()
          .map(
            Either<Failure, List<ViewGroupDetail>>.right,
          )
          .handleError(
            (Object e, StackTrace stackTrace) {
              LoggerService.error(
                '[LibraryDao] Error in watchGroupDetails for group: $groupId',
                e,
                stackTrace,
              );
              return Either<Failure, List<ViewGroupDetail>>.left(
                DatabaseFailure(e.toString(), stackTrace),
              );
            },
          );
    } on Exception catch (e, stackTrace) {
      LoggerService.error(
        '[LibraryDao] Error setting up watchGroupDetails for group: $groupId',
        e,
        stackTrace,
      );
      return Stream<Either<Failure, List<ViewGroupDetail>>>.value(
        Either<Failure, List<ViewGroupDetail>>.left(
          DatabaseFailure(e.toString(), stackTrace),
        ),
      );
    }
  }

  Future<Either<Failure, List<ViewGroupDetail>>> getGroupDetails(
    String groupId,
  ) {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[LibraryDao] Error in getGroupDetails for group: $groupId',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        LoggerService.db('Fetching snapshot for group $groupId');
        final view = attachedDatabase.viewGroupDetails;
        final query = select(view)
          ..where((tbl) => tbl.groupId.equals(groupId))
          ..orderBy([
            (tbl) => OrderingTerm(
              expression: tbl.isPrinceps,
              mode: OrderingMode.desc,
            ),
            (tbl) => OrderingTerm.asc(tbl.nomCanonique),
          ]);
        final results = await query.get();
        return results;
      },
    );
  }

  Future<Either<Failure, List<ViewGroupDetail>>> fetchRelatedPrinceps(
    String groupId,
  ) {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[LibraryDao] Error in fetchRelatedPrinceps for group: $groupId',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        LoggerService.db('Fetching related princeps for $groupId');
        final targetSummaries = await (select(
          medicamentSummary,
        )..where((tbl) => tbl.groupId.equals(groupId))).get();
        if (targetSummaries.isEmpty) return <ViewGroupDetail>[];

        final commonPrincipes = targetSummaries.first.principesActifsCommuns;
        if (commonPrincipes.isEmpty) return <ViewGroupDetail>[];

        final candidateSummaries =
            await (select(medicamentSummary)..where(
                  (tbl) =>
                      tbl.groupId.isNotValue(groupId) &
                      tbl.isPrinceps.equals(true),
                ))
                .get();

        final relatedGroupIds = <String>{};
        for (final summary in candidateSummaries) {
          final rowPrincipes = summary.principesActifsCommuns;
          final hasAllCommon = commonPrincipes.every(rowPrincipes.contains);
          final hasAdditional = rowPrincipes.length > commonPrincipes.length;

          if (hasAllCommon && hasAdditional && summary.groupId != null) {
            relatedGroupIds.add(summary.groupId!);
          }
        }

        if (relatedGroupIds.isEmpty) return <ViewGroupDetail>[];

        final view = attachedDatabase.viewGroupDetails;
        final relatedQuery = select(view)
          ..where((tbl) => tbl.groupId.isIn(relatedGroupIds.toList()))
          ..where((tbl) => tbl.isPrinceps.equals(true))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.princepsDeReference)]);

        final results = await relatedQuery.get();
        return results;
      },
    );
  }

  Future<Either<Failure, Map<String, dynamic>>> getDatabaseStats() {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[LibraryDao] Error in getDatabaseStats',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        final totalMedicamentsQuery = selectOnly(medicaments)
          ..addColumns([medicaments.codeCip.count()]);
        final totalMedicaments = await totalMedicamentsQuery.getSingle();

        final totalGeneriquesQuery = selectOnly(groupMembers)
          ..addColumns([groupMembers.codeCip.count()])
          ..where(groupMembers.type.equals(1));
        final totalGeneriques = await totalGeneriquesQuery.getSingle();

        final totalPrincipesQuery = selectOnly(principesActifs)
          ..addColumns([principesActifs.principe.count(distinct: true)]);
        final totalPrincipes = await totalPrincipesQuery.getSingle();

        final countMeds =
            totalMedicaments.read(medicaments.codeCip.count()) ?? 0;
        final countGens =
            totalGeneriques.read(groupMembers.codeCip.count()) ?? 0;
        final countPrincipes =
            totalPrincipes.read(
              principesActifs.principe.count(distinct: true),
            ) ??
            0;

        final countPrinceps = countMeds - countGens;

        var ratioGenPerPrincipe = 0.0;
        if (countPrincipes > 0) {
          ratioGenPerPrincipe = countGens / countPrincipes;
        }

        return {
          'total_princeps': countPrinceps,
          'total_generiques': countGens,
          'total_principes': countPrincipes,
          'avg_gen_per_principe': ratioGenPerPrincipe,
        };
      },
    );
  }

  Future<Either<Failure, List<GenericGroupEntity>>> getGenericGroupSummaries({
    List<String>? routeKeywords,
    List<String>? formKeywords,
    List<String>? excludeKeywords,
    List<String>? procedureTypeKeywords,
    String? atcClass,
    int limit = 100,
    int offset = 0,
  }) {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[LibraryDao] Error in getGenericGroupSummaries',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        // Build WHERE expression using Drift's Expression API
        final tbl = medicamentSummary;

        // Base filter: group_id must not be null (standalone medications excluded)
        // Also exclude empty groups (NULL, empty string, or '[]' JSON array)
        var filterExpression =
            tbl.groupId.isNotNull() &
            tbl.principesActifsCommuns.isNotNull() &
            tbl.principesActifsCommuns.isNotValue('[]') &
            tbl.principesActifsCommuns.isNotValue('');

        if (procedureTypeKeywords != null && procedureTypeKeywords.isNotEmpty) {
          final procedureFilters = procedureTypeKeywords
              .map((kw) => tbl.procedureType.like('%$kw%'))
              .toList();
          final procedureFilter = procedureFilters.reduce((a, b) => a | b);
          filterExpression = filterExpression & procedureFilter;
        }

        if (atcClass != null && atcClass.isNotEmpty) {
          filterExpression = filterExpression & tbl.atcCode.like('$atcClass%');
        }

        if (routeKeywords != null && routeKeywords.isNotEmpty) {
          final routeFilters = routeKeywords
              .map((kw) => tbl.voiesAdministration.like('%$kw%'))
              .toList();
          final routeFilter = routeFilters.reduce((a, b) => a | b);
          filterExpression = filterExpression & routeFilter;
        } else if (formKeywords != null && formKeywords.isNotEmpty) {
          // Build OR expression for form keywords
          final formFilters = formKeywords
              .map((kw) => tbl.formePharmaceutique.like('%$kw%'))
              .toList();
          final formFilter = formFilters.reduce((a, b) => a | b);
          filterExpression = filterExpression & formFilter;

          // Add AND expressions for exclude keywords
          if (excludeKeywords != null && excludeKeywords.isNotEmpty) {
            final excludeFilters = excludeKeywords
                .map((kw) => tbl.formePharmaceutique.like('%$kw%').not())
                .toList();
            final excludeFilter = excludeFilters.reduce((a, b) => a & b);
            filterExpression = filterExpression & excludeFilter;
          }
        }

        final query = selectOnly(medicamentSummary)
          ..addColumns([
            tbl.groupId,
            tbl.princepsDeReference,
            tbl.principesActifsCommuns,
          ])
          ..where(filterExpression)
          ..groupBy([
            tbl.groupId,
            tbl.princepsDeReference,
            tbl.principesActifsCommuns,
          ])
          ..orderBy([OrderingTerm.asc(tbl.princepsDeReference)])
          ..limit(limit, offset: offset);

        final rows = await query.get();

        final results = rows
            .map((row) {
              final groupId = row.read(tbl.groupId)!;
              final rawPrincepsReference = row.read(tbl.princepsDeReference)!;
              final princepsReference = extractPrincepsLabel(
                rawPrincepsReference,
              );
              final dynamic rawPrincipes = row.read(tbl.principesActifsCommuns);
              final List<String> principesActifsList;
              if (rawPrincipes is String) {
                principesActifsList = const StringListConverter().fromSql(
                  rawPrincipes,
                );
              } else if (rawPrincipes is List) {
                principesActifsList = rawPrincipes.cast<String>();
              } else {
                principesActifsList = const <String>[];
              }

              final commonPrincipes = formatCommonPrincipesFromList(
                principesActifsList,
              );

              return GenericGroupEntity(
                groupId: groupId,
                commonPrincipes: commonPrincipes,
                princepsReferenceName: princepsReference,
              );
            })
            .where((entity) => entity.commonPrincipes.isNotEmpty)
            .toList();

        return results;
      },
    );
  }

  Future<Either<Failure, bool>> hasExistingData() {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[LibraryDao] Error in hasExistingData',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        final summaryCountQuery = selectOnly(medicamentSummary)
          ..addColumns([medicamentSummary.cisCode.count()]);
        final totalSummaryRows = await summaryCountQuery.getSingle();
        final count =
            totalSummaryRows.read(medicamentSummary.cisCode.count()) ?? 0;

        return count > 0;
      },
    );
  }

  Future<Either<Failure, List<String>>> getDistinctProcedureTypes() {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[LibraryDao] Error in getDistinctProcedureTypes',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        final query = attachedDatabase.customSelect(
          '''
      SELECT DISTINCT procedure_type
      FROM medicament_summary
      WHERE procedure_type IS NOT NULL AND procedure_type != ''
      ORDER BY procedure_type
      ''',
          readsFrom: {medicamentSummary},
        );
        final results = await query.get();
        final procedureTypes = results
            .map((row) => row.read<String>('procedure_type'))
            .toList();
        return procedureTypes;
      },
    );
  }

  Future<Either<Failure, List<String>>> getDistinctRoutes() {
    return Either.catchFutureError(
      (e, stackTrace) {
        LoggerService.error(
          '[LibraryDao] Error in getDistinctRoutes',
          e,
          stackTrace,
        );
        return DatabaseFailure(e.toString(), stackTrace);
      },
      () async {
        final query = attachedDatabase.customSelect(
          '''
      SELECT DISTINCT voies_administration
      FROM medicament_summary
      WHERE voies_administration IS NOT NULL AND voies_administration != ''
      ORDER BY voies_administration
      ''',
          readsFrom: {medicamentSummary},
        );
        final results = await query.get();
        final routes = <String>{};
        for (final row in results) {
          final raw = row.read<String?>('voies_administration');
          if (raw == null || raw.isEmpty) continue;
          final segments = raw.split(';');
          for (final segment in segments) {
            final trimmed = segment.trim();
            if (trimmed.isNotEmpty) {
              routes.add(trimmed);
            }
          }
        }
        final sorted = routes.toList()..sort((a, b) => a.compareTo(b));
        return sorted;
      },
    );
  }
}
