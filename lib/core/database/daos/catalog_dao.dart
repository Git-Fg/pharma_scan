import 'dart:convert';

import 'package:diacritic/diacritic.dart';
import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/models/scan_result.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';

part 'catalog_dao.g.dart';

String _escapeFts5Query(String query) {
  final normalized = removeDiacritics(query.trim()).toLowerCase();
  if (normalized.isEmpty) return '';

  // CRITICAL: Escape FTS5 special characters that can cause syntax errors
  // Replace apostrophes, quotes, colons, and other special chars with spaces
  final escaped = normalized
      .replaceAll("'", ' ') // Apostrophes cause FTS5 syntax errors
      .replaceAll('"', ' ')
      .replaceAll(':', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (escaped.isEmpty) return '';

  final terms = escaped.split(' ').where((t) => t.isNotEmpty).toList();
  if (terms.isEmpty) return '';

  return terms.join(' AND ');
}

@DriftAccessor(
  tables: [
    MedicamentSummary,
    PrincipesActifs,
    Specialites,
    Medicaments,
    MedicamentAvailability,
    GroupMembers,
    GeneriqueGroups,
  ],
)
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.attachedDatabase);

  // ============================================================================
  // Scan Methods (from ScanDao)
  // ============================================================================

  /// WHY: Returns the medicament summary row associated with the scanned CIP.
  /// Scanner UI still needs the CIP itself alongside presentation metadata.
  /// Returns Future directly - exceptions bubble up to Riverpod's AsyncValue.
  Future<ScanResult?> getProductByCip(String codeCip) async {
    LoggerService.db('Lookup product for CIP $codeCip');

    final query = select(medicaments).join([
      leftOuterJoin(
        medicamentAvailability,
        medicamentAvailability.codeCip.equalsExp(medicaments.codeCip),
      ),
    ])..where(medicaments.codeCip.equals(codeCip));

    final row = await query.getSingleOrNull();

    if (row == null) {
      LoggerService.db('No medicament row found for CIP $codeCip');
      return null;
    }

    final medicament = row.readTable(medicaments);
    final availabilityRow = row.readTableOrNull(medicamentAvailability);

    final summary =
        await (select(medicamentSummary)
              ..where((tbl) => tbl.cisCode.equals(medicament.cisCode)))
            .getSingleOrNull();

    if (summary == null) {
      LoggerService.warning(
        '[CatalogDao] No medicament_summary row found for CIS ${medicament.cisCode}',
      );
      return null;
    }

    final result = ScanResult(
      summary: summary,
      cip: codeCip,
      price: medicament.prixPublic,
      refundRate: medicament.tauxRemboursement,
      boxStatus: medicament.commercialisationStatut,
      availabilityStatus: availabilityRow?.statut,
      isHospitalOnly:
          summary.isHospitalOnly ||
          _isHospitalOnly(
            medicament.agrementCollectivites,
            medicament.prixPublic,
            medicament.tauxRemboursement,
          ),
      libellePresentation: medicament.presentationLabel,
    );

    return result;
  }

  bool _isHospitalOnly(
    String? agrementCollectivites,
    double? price,
    String? refundRate,
  ) {
    if (agrementCollectivites == null) return false;
    final agrement = agrementCollectivites.trim().toLowerCase();
    final isAgreed = agrement == 'oui';
    final hasPrice = price != null && price > 0;
    final hasRefund = refundRate != null && refundRate.trim().isNotEmpty;
    return isAgreed && !hasPrice && hasRefund;
  }

  // ============================================================================
  // Search Methods (from SearchDao)
  // ============================================================================

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

  Future<List<MedicamentSummaryData>> searchMedicaments(
    String query, {
    SearchFilters? filters,
  }) async {
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

    return db
        .customSelect(
          queryData.sql,
          variables: queryData.variables,
          readsFrom: {db.medicamentSummary},
        )
        .asyncMap((row) => db.medicamentSummary.mapFromRow(row))
        .watch();
  }

  // ============================================================================
  // Library Methods (from LibraryDao)
  // ============================================================================

  Stream<List<ViewGroupDetail>> watchGroupDetails(
    String groupId,
  ) {
    LoggerService.db(
      'Watching group $groupId via getGroupsWithSamePrinciples',
    );

    return attachedDatabase.getGroupsWithSamePrinciples(groupId).watch();
  }

  Future<List<ViewGroupDetail>> getGroupDetails(
    String groupId,
  ) async {
    LoggerService.db(
      'Fetching snapshot for group $groupId via getGroupsWithSamePrinciples',
    );
    return attachedDatabase.getGroupsWithSamePrinciples(groupId).get();
  }

  Future<List<ViewGroupDetail>> fetchRelatedPrinceps(
    String groupId,
  ) async {
    LoggerService.db('Fetching related princeps for $groupId');

    // Fetch target group's principles (single fast select)
    final targetSummaries = await (select(
      medicamentSummary,
    )..where((tbl) => tbl.groupId.equals(groupId))).get();
    if (targetSummaries.isEmpty) return <ViewGroupDetail>[];

    final commonPrincipes = targetSummaries.first.principesActifsCommuns;
    if (commonPrincipes.isEmpty) return <ViewGroupDetail>[];

    // Convert principles list to JSON array string for SQL parameter
    final targetPrinciplesJson = jsonEncode(commonPrincipes);
    final targetLength = commonPrincipes.length;

    // Call generated SQL query with parameters
    final results = await attachedDatabase
        .getRelatedTherapies(
          groupId,
          targetLength,
          targetPrinciplesJson,
        )
        .get();

    return results;
  }

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

    // Custom expression to extract princeps CIS code
    // SQL: MAX(CASE WHEN is_princeps = 1 THEN cis_code ELSE NULL END)
    const princepsCisExpression = CustomExpression<String>(
      'MAX(CASE WHEN is_princeps = 1 THEN cis_code ELSE NULL END)',
    );

    final query = selectOnly(medicamentSummary)
      ..addColumns([
        tbl.groupId,
        tbl.princepsDeReference,
        tbl.principesActifsCommuns,
        princepsCisExpression,
      ])
      ..where(filterExpression)
      ..groupBy([
        tbl.groupId,
        tbl.princepsDeReference,
        tbl.principesActifsCommuns,
      ])
      ..orderBy([
        OrderingTerm.asc(tbl.princepsDeReference),
      ])
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

          // Additional safety check: if commonPrincipes is empty or only whitespace,
          // skip this entity to prevent grouping issues in the UI
          if (commonPrincipes.trim().isEmpty) {
            return null;
          }

          // Extract princeps CIS code
          final princepsCisCode = row.read(princepsCisExpression);

          return GenericGroupEntity(
            groupId: groupId,
            commonPrincipes: commonPrincipes,
            princepsReferenceName: princepsReference,
            princepsCisCode: princepsCisCode,
          );
        })
        .whereType<GenericGroupEntity>()
        .where((entity) => entity.commonPrincipes.isNotEmpty)
        .toList();

    return results;
  }

  Future<bool> hasExistingData() async {
    final summaryCountQuery = selectOnly(medicamentSummary)
      ..addColumns([medicamentSummary.cisCode.count()]);
    final totalSummaryRows = await summaryCountQuery.getSingle();
    final count = totalSummaryRows.read(medicamentSummary.cisCode.count()) ?? 0;

    return count > 0;
  }

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
    final procedureTypes = results
        .map((row) => row.read<String>('procedure_type'))
        .toList();
    return procedureTypes;
  }

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
