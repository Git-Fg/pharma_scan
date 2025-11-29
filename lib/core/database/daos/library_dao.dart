// lib/core/database/daos/library_dao.dart

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_entity.dart';

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
  LibraryDao(super.db);

  Stream<List<ViewGroupDetail>> watchGroupDetails(String groupId) {
    LoggerService.db('Watching group $groupId via view_group_details');
    final view = attachedDatabase.viewGroupDetails;
    final query = select(view)
      ..where((tbl) => tbl.groupId.equals(groupId))
      ..orderBy([
        (tbl) =>
            OrderingTerm(expression: tbl.isPrinceps, mode: OrderingMode.desc),
        (tbl) => OrderingTerm.asc(tbl.nomCanonique),
      ]);
    return query.watch();
  }

  Future<List<ViewGroupDetail>> getGroupDetails(String groupId) {
    LoggerService.db('Fetching snapshot for group $groupId');
    final view = attachedDatabase.viewGroupDetails;
    final query = select(view)
      ..where((tbl) => tbl.groupId.equals(groupId))
      ..orderBy([
        (tbl) =>
            OrderingTerm(expression: tbl.isPrinceps, mode: OrderingMode.desc),
        (tbl) => OrderingTerm.asc(tbl.nomCanonique),
      ]);
    return query.get();
  }

  Future<List<ViewGroupDetail>> fetchRelatedPrinceps(String groupId) async {
    LoggerService.db('Fetching related princeps for $groupId');
    final targetSummaries = await (select(
      medicamentSummary,
    )..where((tbl) => tbl.groupId.equals(groupId))).get();
    if (targetSummaries.isEmpty) return [];

    final commonPrincipes = targetSummaries.first.principesActifsCommuns;
    if (commonPrincipes.isEmpty) return [];

    final candidateSummaries =
        await (select(medicamentSummary)..where(
              (tbl) =>
                  tbl.groupId.isNotValue(groupId) & tbl.isPrinceps.equals(true),
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

    if (relatedGroupIds.isEmpty) return [];

    final view = attachedDatabase.viewGroupDetails;
    final relatedQuery = select(view)
      ..where((tbl) => tbl.groupId.isIn(relatedGroupIds.toList()))
      ..where((tbl) => tbl.isPrinceps.equals(true))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.princepsDeReference)]);

    return relatedQuery.get();
  }

  // WHY: Retrieves global statistics for the dashboard.
  // Provides overview of database content: princeps count, generics count, principles count, and average generics per principle.
  Future<Map<String, dynamic>> getDatabaseStats() async {
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

    final countMeds = totalMedicaments.read(medicaments.codeCip.count()) ?? 0;
    final countGens = totalGeneriques.read(groupMembers.codeCip.count()) ?? 0;
    final countPrincipes =
        totalPrincipes.read(principesActifs.principe.count(distinct: true)) ??
        0;

    final countPrinceps = countMeds - countGens;

    // WHY: Calculate average generics per principle for statistical insight.
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
  }

  Future<List<GenericGroupEntity>> getGenericGroupSummaries({
    List<String>? routeKeywords,
    List<String>? formKeywords,
    List<String>? excludeKeywords,
    List<String>? procedureTypeKeywords,
    String? atcClass,
    int limit = 100,
    int offset = 0,
  }) async {
    // WHY: Use the new MedicamentSummary table for much simpler and faster queries
    // This eliminates complex joins and Dart-based grouping logic
    // WHY: Use Drift Expression API instead of string interpolation for type safety and automatic SQL escaping
    // WHY: Use selectOnly with GROUP BY to aggregate at database level, ensuring pagination applies to groups, not raw rows

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
      // WHY: medicament_summary already has procedureType denormalized, so we can query directly
      // without needing EXISTS subquery with specialites table
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

    // WHY: Use selectOnly with GROUP BY to aggregate at database level before pagination
    // This ensures LIMIT/OFFSET applies to groups, not individual medicament rows
    // Using MIN() for principes_actifs_communs since all rows in a group have the same value
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

    // Convert TypedResult rows directly to GenericGroupEntity objects
    // WHY: selectOnly bypasses TypeConverter, so principesActifsCommuns is returned as String (JSON)
    // We decode it manually and format it using the existing helper function
    return rows
        .map((row) {
          final groupId = row.read(tbl.groupId)!;
          final rawPrincepsReference = row.read(tbl.princepsDeReference)!;
          final princepsReference = extractPrincepsLabel(rawPrincepsReference);
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
  }

  Future<bool> hasExistingData() async {
    final summaryCountQuery = selectOnly(medicamentSummary)
      ..addColumns([medicamentSummary.cisCode.count()]);
    final totalSummaryRows = await summaryCountQuery.getSingle();
    final count = totalSummaryRows.read(medicamentSummary.cisCode.count()) ?? 0;

    return count > 0;
  }

  // WHY: Get distinct procedure types for filter dropdown
  Future<List<String>> getDistinctProcedureTypes() async {
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
    return results.map((row) => row.read<String>('procedure_type')).toList();
  }

  // WHY: Get distinct pharmaceutical forms for filter dropdown
  Future<List<String>> getDistinctRoutes() async {
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
  }
}
