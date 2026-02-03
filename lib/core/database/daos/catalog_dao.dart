import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
// semantic types are not used directly here; keep imports minimal
import 'package:pharma_scan/core/models/scan_models.dart';

// views.drift is not directly referenced; remove to avoid unused import
import 'package:pharma_scan/core/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/core/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/core/domain/models/database_stats.dart';
import 'package:pharma_scan/core/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/core/utils/cip_utils.dart';

/// DAO pour les opérations sur le catalogue de médicaments.
///
/// Les tables BDPM sont définies dans le schéma SQL et accessibles via
/// les requêtes générées (queries.drift) ou customSelect/customUpdate.
///
/// Modern Drift Best Practices (v2.18+) - SQL-First Mapping:
/// Les requêtes dans queries.drift utilisent l'opérateur ** pour le mappage automatique,
/// ce qui élimine le code de mappage manuel et fournit une sécurité de type stricte.
/// Exemple: m.** mappe automatiquement toutes les colonnes de la table 'medicaments'
/// vers une classe générée automatiquement (SearchProductsResult, etc.).
@DriftAccessor()
class CatalogDao extends DatabaseAccessor<AppDatabase> {
  CatalogDao(super.attachedDatabase);

  // ============================================================================
  // Scan Methods
  // ============================================================================

  /// Returns the medicament summary row associated with the scanned CIP.
  /// Scanner UI still needs the CIP itself alongside presentation metadata.
  /// Returns Future directly - exceptions bubble up to Riverpod's AsyncValue.
  ///
  /// **Phase 4 Refactoring**: Now uses denormalized `product_scan_cache` table.
  /// This eliminates the 4-table JOIN (medicament_summary + medicaments + laboratories + medicament_availability)
  /// with a single-table query using primary key access. ✨ Zero overhead
  Future<ScanResult?> getProductByCip(
    Cip13 codeCip, {
    DateTime? expDate,
  }) async {
    attachedDatabase.logger.db('Lookup product for CIP $codeCip');

    final cipString = codeCip.toString();

    // 1. Try exact match (Fastest)
    var cache = await attachedDatabase.managers.productScanCache
        .filter((f) => f.cipCode.equals(cipString))
        .getSingleOrNull();

    // 2. Fallback: Search by CIP7 if exact match fails
    // This handles cases where the scanned CIP13 is old but a newer CIP13 exists with same CIP7
    if (cache == null) {
      final cip7 = CipUtils.extractCip7(cipString);
      if (cip7 != null) {
        attachedDatabase.logger.db(
            'Exact match failed. Trying fallback with CIP7: $cip7 for $cipString');

        // Note: multiple items might share CIP7? Usually minimal, pick first found.
        // In pharmacy logic, CIP7 is the pivot.
        cache = await attachedDatabase.managers.productScanCache
            .filter((f) => f.cip7.equals(cip7))
            .getSingleOrNull();
      }
    }

    if (cache == null) {
      attachedDatabase.logger
          .db('No medicament found in cache for CIP $cipString');
      return null;
    }

    return (
      summary: MedicamentEntity.fromProductCache(cache),
      cip: codeCip,
      price: cache.prixPublic,
      refundRate: cache.tauxRemboursement,
      boxStatus: cache.commercialisationStatut,
      availabilityStatus: cache.availabilityStatus,
      isHospitalOnly: cache.isHospital == 1,
      libellePresentation: null,
      expDate: expDate,
    );
  }

  // ============================================================================
  // Library Methods
  // ============================================================================

  Stream<List<GroupDetailEntity>> watchGroupDetails(
    String groupId,
  ) {
    attachedDatabase.logger.db(
      'Watching group $groupId via getGroupsWithSamePrinciples query',
    );

    return attachedDatabase.queriesDrift
        .getGroupsWithSamePrinciples(targetGroupId: groupId)
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => GroupDetailEntity.fromData(row),
              )
              .toList(),
        );
  }

  Future<List<GroupDetailEntity>> getGroupDetails(
    String groupId,
  ) async {
    attachedDatabase.logger.db(
      'Fetching snapshot for group $groupId via ui_group_details table',
    );

    // ✅ NEW: Using TableManager API instead of complex view
    final rows = await attachedDatabase.managers.uiGroupDetails
        .filter((f) => f.groupId.equals(groupId))
        .orderBy((o) => o.isPrinceps.desc() & o.nomCanonique.asc())
        .get();

    return rows.map(GroupDetailEntity.fromData).toList();
  }

  Future<List<GroupDetailEntity>> fetchRelatedPrinceps(
    String groupId,
  ) async {
    attachedDatabase.logger.db('Fetching related princeps for $groupId');

    // Fetch target group's principles (single fast select)
    final targetSummaries = await customSelect(
      'SELECT principes_actifs_communs FROM medicament_summary WHERE group_id = ? LIMIT 1',
      variables: [Variable<String>(groupId)],
      readsFrom: {},
    ).get();

    if (targetSummaries.isEmpty) return <GroupDetailEntity>[];

    final principesJson = targetSummaries.first.readNullable<String>(
      'principes_actifs_communs',
    );
    if (principesJson == null || principesJson.isEmpty) {
      return <GroupDetailEntity>[];
    }

    var commonPrincipes = <String>[];
    try {
      final decoded = jsonDecode(principesJson);
      if (decoded is List) {
        commonPrincipes = decoded.map((e) => e.toString()).toList();
      }
    } on FormatException {
      return <GroupDetailEntity>[];
    }

    if (commonPrincipes.isEmpty) return <GroupDetailEntity>[];

    // Convert principles list to JSON array string for SQL parameter
    final targetPrinciplesJson = jsonEncode(commonPrincipes);
    final targetLength = commonPrincipes.length;

    // Call generated SQL query with parameters
    final results = await attachedDatabase.queriesDrift
        .getRelatedTherapies(
          targetGroupId: groupId,
          targetLength: targetLength,
          targetPrinciples: targetPrinciplesJson,
        )
        .get();

    return results.map(GroupDetailEntity.fromData).toList();
  }

  // REMOVED: searchMedicaments method - migrated to cluster-based search
// Use ExplorerDao.watchClusters() with clusterSearchProvider instead
// Migration to cluster-first architecture completed

  Future<DatabaseStats> getDatabaseStats() async {
    try {
      // ✅ NEW: Using pre-computed ui_stats table (single row fetch)
      final stats = await attachedDatabase.managers.uiStats.getSingleOrNull();

      if (stats == null) {
        // Return empty stats if table doesn't exist or not populated yet
        return (
          totalPrinceps: 0,
          totalGeneriques: 0,
          totalPrincipes: 0,
          avgGenPerPrincipe: 0.0,
        );
      }

      var ratioGenPerPrincipe = 0.0;
      final totalPrincipes = stats.totalPrincipes ?? 0;
      final totalGeneriques = stats.totalGeneriques ?? 0;
      final totalPrinceps = stats.totalPrinceps ?? 0;

      if (totalPrincipes > 0) {
        ratioGenPerPrincipe = totalGeneriques / totalPrincipes;
      }

      return (
        totalPrinceps: totalPrinceps,
        totalGeneriques: totalGeneriques,
        totalPrincipes: totalPrincipes,
        avgGenPerPrincipe: ratioGenPerPrincipe,
      );
    } catch (_) {
      // Return empty stats if table doesn't exist or other DB error
      return (
        totalPrinceps: 0,
        totalGeneriques: 0,
        totalPrincipes: 0,
        avgGenPerPrincipe: 0.0,
      );
    }
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
    // ✅ NEW: Using pre-computed ui_explorer_list table with TableManager API
    final uelRows = await attachedDatabase.managers.uiExplorerList
        .orderBy((o) => o.title.asc())
        .limit(limit, offset: offset)
        .get();

    final results = <GenericGroupEntity>[];

    for (final uelData in uelRows) {
      // Get the corresponding medicament_summary data for the cluster
      final summary = await attachedDatabase.managers.medicamentSummary
          .filter((f) => f.clusterId.equals(uelData.clusterId))
          .getSingleOrNull();

      if (summary == null) continue;

      final clusterId = uelData.clusterId;
      if (clusterId.isEmpty) continue;

      final princepsReference = summary.princepsDeReference;
      final commonPrincipes = summary.principesActifsCommuns;

      if (commonPrincipes == null ||
          commonPrincipes.trim().isEmpty ||
          princepsReference.isEmpty) {
        continue;
      }

      final princepsCisCodeRaw = uelData.representativeCis ?? '';
      final princepsCisCode = princepsCisCodeRaw.isNotEmpty
          ? (princepsCisCodeRaw.length == 8
              ? CisCode.validated(princepsCisCodeRaw)
              : CisCode.unsafe(princepsCisCodeRaw))
          : null;

      results.add(GenericGroupEntity(
        groupId: GroupId.validated(clusterId),
        commonPrincipes: commonPrincipes,
        princepsReferenceName: princepsReference,
        princepsCisCode: princepsCisCode,
      ));
    }

    return results
        .where((entity) => entity.commonPrincipes.isNotEmpty)
        .toList();
  }

  Future<bool> hasExistingData() async {
    final count = await attachedDatabase.managers.medicamentSummary.count();
    return count > 0;
  }

  Future<List<String>> getDistinctProcedureTypes() async {
    final ms = attachedDatabase.medicamentSummary;
    final query = attachedDatabase.selectOnly(ms, distinct: true)
      ..addColumns([ms.procedureType])
      ..where(ms.procedureType.isNotNull() & ms.procedureType.equals('').not())
      ..orderBy([OrderingTerm.asc(ms.procedureType)]);
    final results = await query.get();
    return results
        .map((row) => row.read(ms.procedureType))
        .whereType<String>()
        .toList();
  }

  Future<List<String>> getDistinctRoutes() async {
    final ms = attachedDatabase.medicamentSummary;
    final query = attachedDatabase.selectOnly(ms, distinct: true)
      ..addColumns([ms.voiesAdministration])
      ..where(ms.voiesAdministration.isNotNull() &
          ms.voiesAdministration.equals('').not())
      ..orderBy([OrderingTerm.asc(ms.voiesAdministration)]);
    final results = await query.get();

    // Post-process: split semicolon-separated routes into unique values
    final routes = <String>{};
    for (final row in results) {
      final raw = row.read(ms.voiesAdministration);
      if (raw == null || raw.isEmpty) continue;
      for (final segment in raw.split(';')) {
        final trimmed = segment.trim();
        if (trimmed.isNotEmpty) routes.add(trimmed);
      }
    }
    return routes.toList()..sort();
  }
}
