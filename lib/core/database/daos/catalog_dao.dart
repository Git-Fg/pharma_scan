import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';
// semantic types are not used directly here; keep imports minimal
import 'package:pharma_scan/core/models/scan_models.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
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
  Future<ScanResult?> getProductByCip(
    Cip13 codeCip, {
    DateTime? expDate,
  }) async {
    LoggerService.db('Lookup product for CIP $codeCip');

    final cipString = codeCip.toString();

    // Fallback: execute a custom select to ensure we get the medicament_summary row
    final rows = await customSelect(
      '''
      SELECT ms.*, ls.name AS labName, m.prix_public, m.taux_remboursement,
             m.is_hospital AS is_hospital, commercialisation_statut AS commercialisationStatut,
             ma.statut AS availabilityStatut
      FROM reference_db.medicament_summary ms
      INNER JOIN reference_db.medicaments m ON ms.cis_code = m.cis_code
      LEFT JOIN reference_db.laboratories ls ON ls.id = ms.titulaire_id
      LEFT JOIN reference_db.medicament_availability ma ON ma.code_cip = m.code_cip
      WHERE m.code_cip = ?1
      LIMIT 1
      ''',
      variables: [Variable<String>(cipString)],
      readsFrom: {},
    ).get();

    if (rows.isEmpty) {
      LoggerService.db('No medicament row found for CIP $cipString');
      return null;
    }

    final row = rows.first;

    final summary = MedicamentSummaryData(
      groupId: row.read<String>('group_id'),
      cisCode: row.read<String>('cis_code'),
      nomCanonique: row.read<String>('nom_canonique'),
      princepsDeReference: row.read<String>('princeps_de_reference'),
      princepsBrandName: row.read<String>('princeps_brand_name'),
      isPrinceps: row.read<int>('is_princeps') == 1,
      status: row.read<String>('status'),
      formePharmaceutique: row.read<String>('forme_pharmaceutique'),
      voiesAdministration: row.read<String>('voies_administration'),
      principesActifsCommuns: row.read<String>('principes_actifs_communs'),
      formattedDosage: row.read<String>('formatted_dosage'),
      titulaireId: row.read<int>('titulaire_id'),
      procedureType: row.read<String>('procedure_type'),
      conditionsPrescription: row.read<String>('conditions_prescription'),
      isSurveillance: row.read<int>('is_surveillance') == 1,
      atcCode: row.read<String>('atc_code'),
      dateAmm: row.read<String>('date_amm'),
      aggregatedConditions: row.read<String>('aggregated_conditions'),
      ansmAlertUrl: row.read<String>('ansm_alert_url'),
      representativeCip: row.read<String>('representative_cip'),
    );

    double? price;
    final prix = row.readNullable<String>('prix_public');
    if (prix != null && prix.isNotEmpty) {
      price = double.tryParse(prix.replaceAll(',', '.'));
    }

    return (
      summary: MedicamentEntity.fromData(summary,
          labName: row.readNullable<String>('labName')),
      cip: codeCip,
      price: price,
      refundRate: row.readNullable<String>('taux_remboursement'),
      boxStatus: row.readNullable<String>('commercialisationStatut'),
      availabilityStatus: row.readNullable<String>('availabilityStatut'),
      isHospitalOnly: row.read<int>('is_hospital') == 1,
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

  /// Search medicaments using FTS5 with trigram tokenizer for fuzzy matching
  /// Returns Future directly - exceptions bubble up to Riverpod's AsyncValue
  Future<List<MedicamentEntity>> searchMedicaments(
    NormalizedQuery query, {
    int limit = 50,
  }) async {
    LoggerService.db('Searching medicaments for query: ${query.toFtsQuery()}');

    final ftsQuery = query.toFtsQuery();
    if (ftsQuery.isEmpty) {
      return [];
    }

    // Use FTS5 search index - direct query using medicament_summary table
    final results = await customSelect(
      'SELECT '
      'ms.* '
      'FROM search_index si '
      'INNER JOIN medicament_summary ms ON ms.group_id = si.rowid '
      'WHERE search_index MATCH ? '
      'ORDER BY ms.nom_canonique '
      'LIMIT ?',
      variables: [
        Variable<String>(ftsQuery),
        Variable<int>(limit),
      ],
    ).get();

    // Map results to MedicamentEntity using the existing fromData constructor
    return results
        .map((row) => MedicamentEntity.fromData(
              MedicamentSummaryData(
                groupId: row.read<String>('group_id'),
                cisCode: row.read<String>('cis_code'),
                nomCanonique: row.read<String>('nom_canonique'),
                princepsDeReference: row.read<String>('princeps_de_reference'),
                princepsBrandName: row.read<String>('princeps_brand_name'),
                isPrinceps: row.read<int>('is_princeps') == 1,
                status: row.read<String>('status'),
                formePharmaceutique: row.read<String>('forme_pharmaceutique'),
                voiesAdministration: row.read<String>('voies_administration'),
                principesActifsCommuns:
                    row.read<String>('principes_actifs_communs'),
                formattedDosage: row.read<String>('formatted_dosage'),
                titulaireId: row.read<int>('titulaire_id'),
                procedureType: row.read<String>('procedure_type'),
                conditionsPrescription:
                    row.read<String>('conditions_prescription'),
                isSurveillance: row.read<int>('is_surveillance') == 1,
                atcCode: row.read<String>('atc_code'),
                dateAmm: row.read<String>('date_amm'),
                aggregatedConditions: row.read<String>('aggregated_conditions'),
                ansmAlertUrl: row.read<String>('ansm_alert_url'),
                representativeCip: row.read<String>('representative_cip'),
              ),
              labName: null, // Lab name would need separate join if needed
            ))
        .toList();
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
}
