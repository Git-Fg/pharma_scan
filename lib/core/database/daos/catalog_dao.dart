import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/models/scan_models.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/database/views.drift.dart';
import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/database_stats.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';
import 'package:pharma_scan/core/database/queries.drift.dart';

/// Builds an FTS5 query string for trigram tokenizer.
///
/// For trigram FTS5, queries work best as quoted phrases.
/// The trigram tokenizer handles fuzzy matching internally by breaking text
/// into 3-character chunks (e.g., "dol", "oli", "lip"...).
///
/// This means searching "dolipprane" will still match "doliprane" because
/// many trigrams overlap.
///
/// Query strategy:
/// - Normalize the input using [normalizeForSearch] for accent/case consistency
/// - Split into individual terms
/// - Wrap each term in quotes for exact substring matching
/// - Join terms with AND for all-term matching
// FTS formatting is handled by `NormalizedQuery.toFtsQuery()`.

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
  Future<ScanResult?> getProductByCip(
    Cip13 codeCip, {
    DateTime? expDate,
  }) async {
    LoggerService.db('Lookup product for CIP $codeCip');

    final cipString = codeCip.toString();

    // Use generated query from queries.drift - no more manual mapping needed
    final result = await attachedDatabase.queriesDrift
        .getProductByCip(cipCode: cipString)
        .getSingleOrNull();

    if (result == null) {
      LoggerService.db('No medicament row found for CIP $cipString');
      return null;
    }

    // The result already contains all the data mapped directly
    return (
      summary: MedicamentEntity.fromData(result.ms, labName: result.labName),
      cip: codeCip,
      price: result.prixPublic,
      refundRate: result.tauxRemboursement,
      boxStatus: result.commercialisationStatut,
      availabilityStatus: result.availabilityStatut,
      isHospitalOnly: result.ms.isHospital,
      libellePresentation: result.presentationLabel,
      expDate: expDate,
    );
  }

  // ============================================================================
  // Search Methods
  // ============================================================================

  Future<List<MedicamentEntity>> searchMedicaments(
    NormalizedQuery query, {
    SearchFilters? filters,
  }) async {
    final sanitizedQuery = query.toFtsQuery();
    if (sanitizedQuery.isEmpty) {
      LoggerService.db('Empty search query, returning empty results');
      return <MedicamentEntity>[];
    }

    LoggerService.db(
      'Searching medicaments with FTS5 query: $sanitizedQuery',
    );

    final routeFilter = filters?.voieAdministration ?? '';
    final atcFilter = filters?.atcClass?.code ?? '';
    final labFilter = filters?.titulaireId ?? -1;

    // Use Drift-generated query from queries.drift - no manual mapping needed
    final results = await attachedDatabase.queriesDrift
        .searchMedicaments(
          fts: sanitizedQuery,
          routeFilter: routeFilter,
          atcFilter: atcFilter,
          labFilter: labFilter,
        )
        .get();

    return results.map((row) {
      return MedicamentEntity.fromData(row.ms, labName: row.labName);
    }).toList();
  }

  Stream<List<MedicamentEntity>> watchMedicaments(
    NormalizedQuery query, {
    SearchFilters? filters,
  }) {
    final sanitizedQuery = query.toFtsQuery();
    if (sanitizedQuery.isEmpty) {
      LoggerService.db('Empty search query, emitting empty stream');
      return Stream<List<MedicamentEntity>>.value(const <MedicamentEntity>[]);
    }

    LoggerService.db('Watching medicament search for query: $sanitizedQuery');

    final routeFilter = filters?.voieAdministration ?? '';
    final atcFilter = filters?.atcClass?.code ?? '';
    final labFilter = filters?.titulaireId ?? -1;

    return attachedDatabase.queriesDrift
        .watchMedicaments(
          fts: sanitizedQuery,
          routeFilter: routeFilter,
          atcFilter: atcFilter,
          labFilter: labFilter,
        )
        .watch()
        .map(
          (results) => results.map((row) {
            return MedicamentEntity.fromData(row.ms, labName: row.labName);
          }).toList(),
        );
  }

  // ============================================================================
  // SQL-First Mapping Examples: Using the ** operator for automatic mapping
  // ============================================================================
  // NOTE: Older helper methods that relied on LIKE-based `searchProducts`
  // and `watchSearchProducts` were removed in favor of `searchMedicaments`
  // which performs normalized FTS5 searches and supports filters.

  /// Returns clustered search results for UI display
  /// Uses view_search_results to provide cluster, group, and standalone results
  Stream<List<ViewSearchResult>> watchSearchResults(NormalizedQuery query) {
    final sanitizedQuery = query.toFtsQuery();
    if (sanitizedQuery.isEmpty) {
      LoggerService.db('Empty search query, emitting empty stream');
      return Stream<List<ViewSearchResult>>.value(const []);
    }

    LoggerService.db(
        'Watching clustered search results for query: $sanitizedQuery');

    // Filter view_search_results based on display_name and common_principes
    // Use FTS5 MATCH for efficient text search
    return attachedDatabase
        .select(attachedDatabase.viewSearchResults)
        .watch()
        .map((rows) {
      // Apply client-side filtering since FTS5 on views can be complex
      final normalizedSearchTerms =
          query.split(' ').where((term) => term.isNotEmpty).toList();

      if (normalizedSearchTerms.isEmpty) return <ViewSearchResult>[];

      return rows.where((row) {
        final displayName = (row.displayName ?? '').toLowerCase();
        final commonPrincipes = (row.commonPrincipes ?? '').toLowerCase();
        final nomCanonique = (row.nomCanonique ?? '').toLowerCase();

        // Check if all search terms are present in any of the relevant fields
        return normalizedSearchTerms.every((term) =>
            displayName.contains(term) ||
            commonPrincipes.contains(term) ||
            nomCanonique.contains(term));
      }).toList();
    });
  }

  // ============================================================================
  // Library Methods
  // ============================================================================

  Stream<List<GroupDetailEntity>> watchGroupDetails(
    String groupId,
  ) {
    LoggerService.db(
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
    LoggerService.db(
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
    LoggerService.db('Fetching related princeps for $groupId');

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
    final result = await attachedDatabase.queriesDrift
        .getMedicamentSummaryCount()
        .getSingle();
    return result > 0;
  }

  Future<List<String>> getDistinctProcedureTypes() async {
    final query = attachedDatabase.customSelect(
      'SELECT DISTINCT procedure_type ' +
          'FROM medicament_summary ' +
          "WHERE procedure_type IS NOT NULL AND procedure_type != '' " +
          'ORDER BY procedure_type',
      readsFrom: {},
    );
    final results = await query.get();
    final procedureTypes = results
        .map((row) => row.readNullable<String>('procedure_type'))
        .whereType<String>()
        .toList();
    return procedureTypes;
  }

  Future<List<String>> getDistinctRoutes() async {
    final query = attachedDatabase.customSelect(
      'SELECT DISTINCT voies_administration ' +
          'FROM medicament_summary ' +
          "WHERE voies_administration IS NOT NULL AND voies_administration != '' " +
          'ORDER BY voies_administration',
      readsFrom: {},
    );
    final results = await query.get();
    final routes = <String>{};
    for (final row in results) {
      final raw = row.readNullable<String>('voies_administration');
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

  // ============================================================================
  // Additional SQL-First Mapping Examples
  // ============================================================================

  /// Get detailed product information using the ** operator for automatic mapping
  /// Returns a strongly-typed result class with all columns from joined tables
  Future<GetProductDetailsByCipResult?> getProductDetailsByCip(
      String cipCode) async {
    LoggerService.db('Fetching detailed product info for CIP: $cipCode');

    // Use the generated query with automatic mapping via ** operator
    final result = await attachedDatabase.queriesDrift
        .getProductDetailsByCip(cipCode: cipCode)
        .getSingleOrNull();

    return result;
  }

  /// Get all products by laboratory with automatic mapping
  Future<List<GetProductsByLaboratoryResult>> getProductsByLaboratory(
      int labId) async {
    LoggerService.db('Fetching products for laboratory ID: $labId');

    // Use the generated query with automatic mapping via ** operator
    final results = await attachedDatabase.queriesDrift
        .getProductsByLaboratory(labId: labId)
        .get();

    return results;
  }

  /// Get product availability information using the ** operator for automatic mapping
  Future<GetProductAvailabilityResult?> getProductAvailability(
      String cipCode) async {
    LoggerService.db('Fetching availability info for CIP: $cipCode');

    // Use the generated query with automatic mapping via ** operator
    final result = await attachedDatabase.queriesDrift
        .getProductAvailability(cipCode: cipCode)
        .getSingleOrNull();

    return result;
  }
}
