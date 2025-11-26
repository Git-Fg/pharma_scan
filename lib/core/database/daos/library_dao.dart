// lib/core/database/daos/library_dao.dart

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart' as drift_db;
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_entity.dart';

part 'library_dao.g.dart';

// WHY: DTO classes for product group classification data
// These are not mappers, but data transfer objects that aggregate multiple Drift rows
class GroupMemberData {
  const GroupMemberData({
    required this.medicamentRow,
    required this.specialiteRow,
    required this.groupMemberRow,
    required this.summaryRow,
  });

  final drift_db.Medicament medicamentRow;
  final drift_db.Specialite specialiteRow;
  final drift_db.GroupMember groupMemberRow;
  final drift_db.MedicamentSummaryData summaryRow;
}

class ProductGroupData {
  const ProductGroupData({
    required this.groupId,
    required this.memberRows,
    required this.principesByCip,
    required this.commonPrincipes,
    this.relatedPrincepsRows = const [],
  });

  final String groupId;
  final List<GroupMemberData> memberRows;
  final Map<String, List<drift_db.PrincipesActif>> principesByCip;
  final List<String> commonPrincipes;
  final List<GroupMemberData> relatedPrincepsRows;

  // WHY: Get synthetic title for display
  String get syntheticTitle {
    final groupCanonicalName = memberRows.isNotEmpty
        ? memberRows.first.summaryRow.princepsDeReference
        : (commonPrincipes.isNotEmpty ? commonPrincipes.join(' + ') : '');

    if (groupCanonicalName.isEmpty) {
      return 'Groupe $groupId';
    }

    return groupCanonicalName;
  }

  // WHY: Get distinct formulations from member rows
  List<String> get distinctFormulations {
    final formsSet = <String>{};
    for (final memberRow in memberRows) {
      final form = memberRow.specialiteRow.formePharmaceutique?.trim();
      if (form != null && form.isNotEmpty) {
        formsSet.add(form);
      }
    }
    final forms = formsSet.toList()..sort();
    return forms;
  }

  // WHY: Get distinct dosage labels
  List<String> get distinctDosages {
    final dosageLabels = <String>{};
    for (final memberRow in memberRows) {
      final principesData =
          principesByCip[memberRow.medicamentRow.codeCip] ??
          const <drift_db.PrincipesActif>[];
      final firstPrincipe = principesData.isNotEmpty
          ? principesData.first
          : null;

      if (firstPrincipe != null) {
        final dosage = firstPrincipe.dosage;
        final unit = firstPrincipe.dosageUnit ?? '';
        if (dosage != null || unit.isNotEmpty) {
          final formatted = dosage != null
              ? '$dosage${unit.isNotEmpty ? ' $unit' : ''}'
              : unit;
          if (formatted.isNotEmpty) {
            dosageLabels.add(formatted);
          }
        }
      }
    }
    return dosageLabels.toList()..sort();
  }
}

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

  Future<ProductGroupData?> classifyProductGroup(String groupId) async {
    LoggerService.db('Classifying product group $groupId');
    // WHY: Join with MedicamentSummary to access pre-computed cleaned names (nomCanonique)
    // from the parser. This implements Source of Truth 1 (The Parser) in the Triangulation Strategy.
    final groupMembersQuery = select(specialites).join([
      innerJoin(
        medicaments,
        medicaments.cisCode.equalsExp(specialites.cisCode),
      ),
      innerJoin(
        groupMembers,
        groupMembers.codeCip.equalsExp(medicaments.codeCip),
      ),
      innerJoin(
        medicamentSummary,
        medicamentSummary.cisCode.equalsExp(specialites.cisCode),
      ),
    ])..where(groupMembers.groupId.equals(groupId));

    final memberRows = await groupMembersQuery.get();
    if (memberRows.isEmpty) return null;

    final memberCips = memberRows
        .map((row) => row.readTable(medicaments).codeCip)
        .toSet();
    final principesByCip = await _getPrincipesActifsByCip(memberCips);

    final memberDataList = <GroupMemberData>[];
    List<String> commonPrincipes = [];

    for (final row in memberRows) {
      final medData = row.readTable(medicaments);
      final specData = row.readTable(specialites);
      final memberData = row.readTable(groupMembers);
      final summaryData = row.readTable(medicamentSummary);

      memberDataList.add(
        GroupMemberData(
          medicamentRow: medData,
          specialiteRow: specData,
          groupMemberRow: memberData,
          summaryRow: summaryData,
        ),
      );

      // WHY: Extract common principles from the first summary row we find (they are identical for the group)
      if (commonPrincipes.isEmpty) {
        commonPrincipes = summaryData.principesActifsCommuns;
      }
    }

    // WHY: Find related princeps from other groups that contain ALL of the current group's
    // active ingredients PLUS at least one additional ingredient.
    final relatedPrincepsRows = await _findRelatedPrinceps(
      groupId,
      commonPrincipes,
    );

    // WHY: Get principes for related princeps as well
    final relatedCips = relatedPrincepsRows
        .map((row) => row.medicamentRow.codeCip)
        .toSet();
    final relatedPrincipesByCip = await _getPrincipesActifsByCip(relatedCips);
    principesByCip.addAll(relatedPrincipesByCip);

    return ProductGroupData(
      groupId: groupId,
      memberRows: memberDataList,
      principesByCip: principesByCip,
      commonPrincipes: commonPrincipes,
      relatedPrincepsRows: relatedPrincepsRows,
    );
  }

  // WHY: Find princeps from other groups that contain ALL of the current group's
  // active ingredients PLUS at least one additional ingredient.
  Future<List<GroupMemberData>> _findRelatedPrinceps(
    String groupId,
    List<String> commonPrincipes,
  ) async {
    if (commonPrincipes.isEmpty) return [];

    // WHY: Query the denormalized MedicamentSummary source of truth directly to
    // avoid redundant multi-table joins when filtering candidate rows.
    final summaryQuery = select(medicamentSummary)
      ..where(
        (tbl) => tbl.groupId.isNotValue(groupId) & tbl.isPrinceps.equals(true),
      );

    final summaryRows = await summaryQuery.get();
    if (summaryRows.isEmpty) return [];

    final candidateSummaries = <drift_db.MedicamentSummaryData>[];
    for (final summary in summaryRows) {
      final rowPrincipes = summary.principesActifsCommuns;

      // WHY: Related therapies must contain all shared principles plus at least
      // one extra component to be considered an enriched princeps option.
      final hasAllCommon = commonPrincipes.every(rowPrincipes.contains);
      final hasAdditional = rowPrincipes.length > commonPrincipes.length;

      if (hasAllCommon && hasAdditional) {
        candidateSummaries.add(summary);
      }
    }

    if (candidateSummaries.isEmpty) return [];

    final relatedPrincepsRows = <GroupMemberData>[];
    final cisCodes = candidateSummaries.map((row) => row.cisCode).toList();

    // WHY: Hydrate the minimal set of rows (only confirmed matches) to keep the
    // join cost low. Drift 2.24.0+ handles large sets internally.
    final hydratedQuery = select(specialites).join([
      innerJoin(
        medicaments,
        medicaments.cisCode.equalsExp(specialites.cisCode),
      ),
      innerJoin(
        groupMembers,
        groupMembers.codeCip.equalsExp(medicaments.codeCip),
      ),
      innerJoin(
        medicamentSummary,
        medicamentSummary.cisCode.equalsExp(specialites.cisCode),
      ),
    ])..where(specialites.cisCode.isIn(cisCodes));

    final hydratedRows = await hydratedQuery.get();
    for (final row in hydratedRows) {
      relatedPrincepsRows.add(
        GroupMemberData(
          medicamentRow: row.readTable(medicaments),
          specialiteRow: row.readTable(specialites),
          groupMemberRow: row.readTable(groupMembers),
          summaryRow: row.readTable(medicamentSummary),
        ),
      );
    }

    return relatedPrincepsRows;
  }

  Future<Map<String, List<drift_db.PrincipesActif>>> _getPrincipesActifsByCip(
    Set<String> codeCips,
  ) async {
    if (codeCips.isEmpty) return {};

    final results = <String, List<drift_db.PrincipesActif>>{};
    final cipList = codeCips.toList();

    // WHY: Drift 2.24.0+ handles large sets internally, so manual chunking is no longer needed.
    final query = select(principesActifs)
      ..where((tbl) => tbl.codeCip.isIn(cipList));
    final rows = await query.get();

    for (final row in rows) {
      results.putIfAbsent(row.codeCip, () => []).add(row);
    }

    return results;
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
    double ratioGenPerPrincipe = 0.0;
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
    Expression<bool> filterExpression =
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
          final princepsReference = row.read(tbl.princepsDeReference)!;
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
