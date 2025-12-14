import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
// semantic types are not used directly here; keep imports minimal
import 'package:pharma_scan/core/models/scan_models.dart';

// views.drift is not directly referenced; remove to avoid unused import
import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/database_stats.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';

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

    // Single table query with PK lookup - no JOINs!
    // Note: cipCode is an FK to medicaments, so we navigate: cipCode (FK) -> cipCode (column)
    final cache = await attachedDatabase.managers.productScanCache
        .filter((f) => f.cipCode.cipCode.equals(cipString))
        .getSingleOrNull();

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
      'Watching group $groupId via view_group_details',
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
      'Fetching snapshot for group $groupId via view_group_details',
    );

    final rows = await (attachedDatabase
            .select(attachedDatabase.viewGroupDetails)
          ..where((t) => t.groupId.equals(groupId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.isPrinceps, mode: OrderingMode.desc),
            (t) => OrderingTerm(
                expression: t.nomCanonique, mode: OrderingMode.asc),
          ]))
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
    final totalMedicamentsRow = await customSelect(
      'SELECT COUNT(*) AS count FROM medicaments',
      readsFrom: {},
    ).getSingle();
    final countMeds = totalMedicamentsRow.read<int>('count');

    final totalGeneriquesRow = await customSelect(
      'SELECT COUNT(*) AS count FROM group_members WHERE type = 1',
      readsFrom: {},
    ).getSingle();
    final countGens = totalGeneriquesRow.read<int>('count');

    final totalPrincipesRow = await customSelect(
      'SELECT COUNT(DISTINCT principe) AS count FROM principes_actifs',
      readsFrom: {},
    ).getSingle();
    final countPrincipes = totalPrincipesRow.read<int>('count');

    final countPrinceps = countMeds - countGens;

    var ratioGenPerPrincipe = 0.0;
    if (countPrincipes > 0) {
      ratioGenPerPrincipe = countGens / countPrincipes;
    }

    return (
      totalPrinceps: countPrinceps,
      totalGeneriques: countGens,
      totalPrincipes: countPrincipes,
      avgGenPerPrincipe: ratioGenPerPrincipe,
    );
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
    // Query view_explorer_list from backend instead of view_generic_group_summaries
    final query = customSelect(
      'SELECT ' +
          'vel.cluster_id, ' +
          'vel.title, ' +
          'vel.subtitle, ' +
          'vel.secondary_princeps, ' +
          'vel.is_narcotic, ' +
          'vel.variant_count, ' +
          'vel.representative_cis, ' +
          'ms.princeps_de_reference, ' +
          'ms.principes_actifs_communs ' +
          'FROM view_explorer_list vel ' +
          'JOIN medicament_summary ms ON ms.cluster_id = vel.cluster_id ' +
          'WHERE ms.principes_actifs_communs IS NOT NULL ' +
          "AND ms.principes_actifs_communs != '[]' " +
          "AND ms.principes_actifs_communs != '' " +
          'ORDER BY vel.title ' +
          'LIMIT ? OFFSET ?',
      variables: [
        Variable<int>(limit),
        Variable<int>(offset),
      ],
      readsFrom: {},
    );

    final rows = await query.get();

    final results = rows
        .map((row) {
          final clusterId = row.read<String>('cluster_id');
          if (clusterId.isEmpty) return null;

          final princepsReference = row.readNullable<String>('subtitle');
          final commonPrincipes = row.readNullable<String>(
            'principes_actifs_communs',
          );

          if (commonPrincipes == null ||
              commonPrincipes.trim().isEmpty ||
              princepsReference == null ||
              princepsReference.isEmpty) {
            return null;
          }

          final princepsCisCodeRaw =
              row.readNullable<String>('representative_cis') ?? '';
          final princepsCisCode = princepsCisCodeRaw.isNotEmpty
              ? (princepsCisCodeRaw.length == 8
                  ? CisCode.validated(princepsCisCodeRaw)
                  : CisCode.unsafe(princepsCisCodeRaw))
              : null;

          return GenericGroupEntity(
            groupId: GroupId.validated(clusterId),
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
