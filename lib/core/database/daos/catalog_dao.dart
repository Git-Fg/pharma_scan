import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/daos/catalog_dao.drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/dbschema.drift.dart';
import 'package:pharma_scan/core/database/queries.drift.dart';
import 'package:pharma_scan/core/database/views.drift.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/models/scan_result.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/database_stats.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';

// Extension to convert query result types to MedicamentSummaryData
extension QueryResultToMedicamentSummaryData on SearchMedicamentsResult {
  MedicamentSummaryData toMedicamentSummaryData() {
    return MedicamentSummaryData(
      cisCode: cisCode,
      nomCanonique: nomCanonique,
      princepsDeReference: princepsDeReference,
      isPrinceps: isPrinceps,
      clusterId: clusterId,
      groupId: groupId,
      principesActifsCommuns: principesActifsCommuns,
      formattedDosage: formattedDosage,
      formePharmaceutique: formePharmaceutique,
      voiesAdministration: voiesAdministration,
      memberType: memberType,
      princepsBrandName: princepsBrandName,
      procedureType: procedureType,
      titulaireId: titulaireId,
      conditionsPrescription: conditionsPrescription,
      dateAmm: dateAmm,
      isSurveillance: isSurveillance,
      atcCode: atcCode,
      status: status,
      priceMin: priceMin,
      priceMax: priceMax,
      aggregatedConditions: aggregatedConditions,
      ansmAlertUrl: ansmAlertUrl,
      isHospital: isHospital,
      isDental: isDental,
      isList1: isList1,
      isList2: isList2,
      isNarcotic: isNarcotic,
      isException: isException,
      isRestricted: isRestricted,
      isOtc: isOtc,
      smrNiveau: smrNiveau,
      smrDate: smrDate,
      asmrNiveau: asmrNiveau,
      asmrDate: asmrDate,
      urlNotice: urlNotice,
      hasSafetyAlert: hasSafetyAlert,
      representativeCip: representativeCip,
    );
  }
}

// Extension for WatchMedicamentsResult
extension WatchQueryResultToMedicamentSummaryData on WatchMedicamentsResult {
  MedicamentSummaryData toMedicamentSummaryData() {
    return MedicamentSummaryData(
      cisCode: cisCode,
      nomCanonique: nomCanonique,
      princepsDeReference: princepsDeReference,
      isPrinceps: isPrinceps,
      clusterId: clusterId,
      groupId: groupId,
      principesActifsCommuns: principesActifsCommuns,
      formattedDosage: formattedDosage,
      formePharmaceutique: formePharmaceutique,
      voiesAdministration: voiesAdministration,
      memberType: memberType,
      princepsBrandName: princepsBrandName,
      procedureType: procedureType,
      titulaireId: titulaireId,
      conditionsPrescription: conditionsPrescription,
      dateAmm: dateAmm,
      isSurveillance: isSurveillance,
      atcCode: atcCode,
      status: status,
      priceMin: priceMin,
      priceMax: priceMax,
      aggregatedConditions: aggregatedConditions,
      ansmAlertUrl: ansmAlertUrl,
      isHospital: isHospital,
      isDental: isDental,
      isList1: isList1,
      isList2: isList2,
      isNarcotic: isNarcotic,
      isException: isException,
      isRestricted: isRestricted,
      isOtc: isOtc,
      smrNiveau: smrNiveau,
      smrDate: smrDate,
      asmrNiveau: asmrNiveau,
      asmrDate: asmrDate,
      urlNotice: urlNotice,
      hasSafetyAlert: hasSafetyAlert,
      representativeCip: representativeCip,
    );
  }
}

// Extension for GetProductByCipResult
extension GetProductByCipResultToMedicamentSummaryData on GetProductByCipResult {
  MedicamentSummaryData toMedicamentSummaryData() {
    return MedicamentSummaryData(
      cisCode: cisCode1, // Note: duplicated field in query result
      nomCanonique: nomCanonique,
      princepsDeReference: princepsDeReference,
      isPrinceps: isPrinceps,
      clusterId: clusterId,
      groupId: groupId,
      principesActifsCommuns: principesActifsCommuns,
      formattedDosage: formattedDosage,
      formePharmaceutique: formePharmaceutique,
      voiesAdministration: voiesAdministration,
      memberType: memberType,
      princepsBrandName: princepsBrandName,
      procedureType: procedureType,
      titulaireId: titulaireId,
      conditionsPrescription: conditionsPrescription,
      dateAmm: dateAmm,
      isSurveillance: isSurveillance,
      atcCode: atcCode,
      status: status,
      priceMin: priceMin,
      priceMax: priceMax,
      aggregatedConditions: aggregatedConditions,
      ansmAlertUrl: ansmAlertUrl,
      isHospital: isHospital,
      isDental: isDental,
      isList1: isList1,
      isList2: isList2,
      isNarcotic: isNarcotic,
      isException: isException,
      isRestricted: isRestricted,
      isOtc: isOtc,
      smrNiveau: smrNiveau,
      smrDate: smrDate,
      asmrNiveau: asmrNiveau,
      asmrDate: asmrDate,
      urlNotice: urlNotice,
      hasSafetyAlert: hasSafetyAlert,
      representativeCip: representativeCip,
    );
  }
}

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
String _buildFtsQuery(String raw) {
  final normalized = normalizeForSearch(raw);
  if (normalized.isEmpty) return '';
  final terms = normalized.split(' ').where((t) => t.isNotEmpty).toList();
  if (terms.isEmpty) return '';

  // For trigram, we just quote each term and join with AND
  // The trigram tokenizer will find fuzzy matches automatically
  final parts = terms.map((term) => '"$term"').toList();
  return parts.join(' AND ');
}

/// DAO pour les opérations sur le catalogue de médicaments.
///
/// Les tables BDPM sont définies dans le schéma SQL et accessibles via
/// les requêtes générées (queries.drift) ou customSelect/customUpdate.
@DriftAccessor()
class CatalogDao extends DatabaseAccessor<AppDatabase> with $CatalogDaoMixin {
  CatalogDao(super.attachedDatabase);

  // ============================================================================
  // Scan Methods (from ScanDao)
  // ============================================================================

  /// WHY: Returns the medicament summary row associated with the scanned CIP.
  /// Scanner UI still needs the CIP itself alongside presentation metadata.
  /// Returns Future directly - exceptions bubble up to Riverpod's AsyncValue.
  Future<ScanResult?> getProductByCip(
    Cip13 codeCip, {
    DateTime? expDate,
  }) async {
    LoggerService.db('Lookup product for CIP $codeCip');

    final cipString = codeCip.toString();

    // Use generated query from queries.drift - no more manual mapping needed
    final result = await attachedDatabase.queriesDrift.getProductByCip(cipCode: cipString).getSingleOrNull();

    if (result == null) {
      LoggerService.db('No medicament row found for CIP $cipString');
      return null;
    }

    // Direct mapping from generated result using extension method
    final scanResult = ScanResult(
      summary: MedicamentEntity.fromData(result.toMedicamentSummaryData(), labName: result.labName),
      cip: codeCip,
      metadata: (
        price: result.prixPublic,
        refundRate: result.tauxRemboursement,
        boxStatus: result.commercialisationStatut,
        availabilityStatus: result.availabilityStatut,
        // FIXED: Now rely solely on the database isHospital flag
        // The backend now handles all hospital-only logic centrally
        isHospitalOnly: result.isHospital,
        libellePresentation: result.presentationLabel,
        expDate: expDate,
      ),
    );

    return scanResult;
  }

  
  // ============================================================================
  // Search Methods (from SearchDao)
  // ============================================================================

  Future<List<MedicamentEntity>> searchMedicaments(
    NormalizedQuery query, {
    SearchFilters? filters,
  }) async {
    final sanitizedQuery = _buildFtsQuery(query.toString());
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
    final results = await attachedDatabase.queriesDrift.searchMedicaments(
      fts: sanitizedQuery,
      routeFilter: routeFilter,
      atcFilter: atcFilter,
      labFilter: labFilter,
    ).get();

    // Direct mapping from generated results using extension method
    return results.map((row) {
      return MedicamentEntity.fromData(row.toMedicamentSummaryData(), labName: row.labName);
    }).toList();
  }

  Stream<List<MedicamentEntity>> watchMedicaments(
    NormalizedQuery query, {
    SearchFilters? filters,
  }) {
    final sanitizedQuery = _buildFtsQuery(query.toString());
    if (sanitizedQuery.isEmpty) {
      LoggerService.db('Empty search query, emitting empty stream');
      return Stream<List<MedicamentEntity>>.value(const <MedicamentEntity>[]);
    }

    LoggerService.db('Watching medicament search for query: $sanitizedQuery');

    final routeFilter = filters?.voieAdministration ?? '';
    final atcFilter = filters?.atcClass?.code ?? '';
    final labFilter = filters?.titulaireId ?? -1;

    // Use generated query from queries.drift - no manual mapping needed
    return attachedDatabase.queriesDrift.watchMedicaments(
      fts: sanitizedQuery,
      routeFilter: routeFilter,
      atcFilter: atcFilter,
      labFilter: labFilter,
    ).watch().map(
          (results) => results.map((row) {
            return MedicamentEntity.fromData(row.toMedicamentSummaryData(), labName: row.labName);
          }).toList(),
        );
  }

  /// Watch search results from view_search_results, filtered by normalized query.
  /// The view organizes data into clusters, groups, and standalone medicaments.
  Stream<List<ViewSearchResult>> watchSearchResultsSql(
    NormalizedQuery query,
  ) {
    final normalizedQuery = normalizeForSearch(query.toString());
    if (normalizedQuery.isEmpty) {
      LoggerService.db('Empty search query, emitting empty stream');
      return Stream<List<ViewSearchResult>>.value(const <ViewSearchResult>[]);
    }

    LoggerService.db('Watching search results for query: $normalizedQuery');

    // Filter by matching the normalized query against relevant fields
    // For clusters/groups: match against normalized_common or display_name
    // For standalone: match against nom_canonique or display_name
    return customSelect(
      '''
      SELECT * FROM view_search_results
      WHERE 
        (normalized_common IS NOT NULL AND LOWER(normalized_common) LIKE '%' || LOWER(?) || '%')
        OR (display_name IS NOT NULL AND LOWER(display_name) LIKE '%' || LOWER(?) || '%')
        OR (nom_canonique IS NOT NULL AND LOWER(nom_canonique) LIKE '%' || LOWER(?) || '%')
        OR (sort_key IS NOT NULL AND LOWER(sort_key) LIKE '%' || LOWER(?) || '%')
      ORDER BY 
        CASE type
          WHEN 'cluster' THEN 1
          WHEN 'group' THEN 2
          WHEN 'standalone' THEN 3
        END,
        sort_key
      LIMIT 100
      ''',
      variables: [
        Variable<String>(normalizedQuery),
        Variable<String>(normalizedQuery),
        Variable<String>(normalizedQuery),
        Variable<String>(normalizedQuery),
      ],
      readsFrom: {attachedDatabase.viewSearchResults},
    ).watch().map(
          (rows) => rows
              .map(
                (row) => ViewSearchResult(
                  type: row.read<String>('type'),
                  normalizedCommon: row.read<String?>('normalized_common'),
                  groupId: row.read<String?>('group_id'),
                  commonPrincipes: row.read<String?>('common_principes'),
                  princepsReferenceName: row.read<String?>(
                    'princeps_reference_name',
                  ),
                  princepsCisCode: row.read<String?>('princeps_cis_code'),
                  groupsJson: row.read<String?>('groups_json'),
                  displayName: row.read<String?>('display_name'),
                  sortKey: row.read<String>('sort_key'),
                  cisCode: row.read<String?>('cis_code'),
                  nomCanonique: row.read<String?>('nom_canonique'),
                  isPrinceps: row.read<int?>('is_princeps') == 1,
                  memberType: row.read<int?>('member_type'),
                  principesActifsCommuns: row.read<String?>(
                    'principes_actifs_communs',
                  ),
                  princepsDeReference:
                      row.read<String?>('princeps_de_reference'),
                  formePharmaceutique:
                      row.read<String?>('forme_pharmaceutique'),
                  voiesAdministration:
                      row.read<String?>('voies_administration'),
                  princepsBrandName: row.read<String?>('princeps_brand_name'),
                  procedureType: row.read<String?>('procedure_type'),
                  titulaireId: row.read<int?>('titulaire_id'),
                  conditionsPrescription: row.read<String?>(
                    'conditions_prescription',
                  ),
                  dateAmm: row.read<String?>('date_amm'),
                  isSurveillance: row.read<int?>('is_surveillance') == 1,
                  formattedDosage: row.read<String?>('formatted_dosage'),
                  atcCode: row.read<String?>('atc_code'),
                  status: row.read<String?>('status'),
                  priceMin: row.read<double?>('price_min'),
                  priceMax: row.read<double?>('price_max'),
                  aggregatedConditions:
                      row.read<String?>('aggregated_conditions'),
                  ansmAlertUrl: row.read<String?>('ansm_alert_url'),
                  isHospital: row.read<int?>('is_hospital') == 1,
                  isDental: row.read<int?>('is_dental') == 1,
                  isList1: row.read<int?>('is_list1') == 1,
                  isList2: row.read<int?>('is_list2') == 1,
                  isNarcotic: row.read<int?>('is_narcotic') == 1,
                  isException: row.read<int?>('is_exception') == 1,
                  isRestricted: row.read<int?>('is_restricted') == 1,
                  isOtc: row.read<int?>('is_otc') == 1,
                  representativeCip: row.read<String?>('representative_cip'),
                  labName: row.read<String?>('lab_name'),
                ),
              )
              .toList(),
        );
  }

  // ============================================================================
  // Library Methods (from LibraryDao)
  // ============================================================================

  Stream<List<GroupDetailEntity>> watchGroupDetails(
    String groupId,
  ) {
    LoggerService.db(
      'Watching group $groupId via view_cluster_variants',
    );

    return customSelect(
      '''
      SELECT
        vcv.cluster_id,
        vcv.cis_code,
        vcv.label,
        vcv.dosage,
        vcv.form,
        vcv.is_princeps,
        vcv.routes,
        vcv.is_otc,
        vcv.default_cip,
        vcv.prix_public,
        ms.group_id,
        ms.princeps_de_reference,
        ms.princeps_brand_name,
        ms.status,
        ms.forme_pharmaceutique,
        ms.voies_administration,
        ms.principes_actifs_communs,
        ms.formatted_dosage,
        ls.name AS summary_titulaire,
        ms.procedure_type,
        ms.conditions_prescription,
        ms.is_surveillance,
        ms.atc_code,
        ms.member_type,
        ms.ansm_alert_url,
        ms.is_hospital AS is_hospital_only,
        ms.is_dental,
        ms.is_list1,
        ms.is_list2,
        ms.is_narcotic,
        ms.is_exception,
        ms.is_restricted,
        ms.is_otc,
        ms.smr_niveau,
        ms.smr_date,
        ms.asmr_niveau,
        ms.asmr_date,
        ms.url_notice,
        ms.has_safety_alert
      FROM view_cluster_variants vcv
      JOIN medicament_summary ms ON ms.cis_code = vcv.cis_code
      LEFT JOIN laboratories ls ON ls.id = ms.titulaire_id
      WHERE vcv.cluster_id = ?
      ORDER BY vcv.is_princeps DESC, vcv.label
    ''',
      variables: [Variable<String>(groupId)],
      readsFrom: {},
    ).watch().map(
          (rows) => rows
              .map(
                (row) => GroupDetailEntity.fromData(
                  ViewGroupDetail(
                    groupId: row.read<String>('group_id'),
                    codeCip: row.read<String>('default_cip'),
                    rawLabel: row.read<String?>('label'),
                    princepsCisReference: row.read<String?>('cis_code'),
                    cisCode: row.read<String>('cis_code'),
                    nomCanonique: row.read<String>('label'),
                    princepsDeReference:
                        row.read<String>('princeps_de_reference'),
                    princepsBrandName: row.read<String>('princeps_brand_name'),
                    isPrinceps: row.read<int>('is_princeps') == 1,
                    status: row.read<String?>('status'),
                    formePharmaceutique: row.read<String?>('form'),
                    voiesAdministration: row.read<String?>('routes'),
                    principesActifsCommuns: row.read<String?>(
                      'principes_actifs_communs',
                    ),
                    formattedDosage: row.read<String?>('dosage'),
                    summaryTitulaire: row.read<String?>('summary_titulaire'),
                    officialTitulaire: row.read<String?>('summary_titulaire'),
                    nomSpecialite: row.read<String>('label'),
                    procedureType: row.read<String?>('procedure_type'),
                    conditionsPrescription: row.read<String?>(
                      'conditions_prescription',
                    ),
                    isSurveillance: row.read<int>('is_surveillance') == 1,
                    atcCode: row.read<String?>('atc_code'),
                    memberType: row.read<int>('member_type'),
                    prixPublic: row.read<num?>('prix_public')?.toDouble(),
                    ansmAlertUrl: row.read<String?>('ansm_alert_url'),
                    isHospitalOnly: row.read<int>('is_hospital_only') == 1,
                    isDental: row.read<int>('is_dental') == 1,
                    isList1: row.read<int>('is_list1') == 1,
                    isList2: row.read<int>('is_list2') == 1,
                    isNarcotic: row.read<int>('is_narcotic') == 1,
                    isException: row.read<int>('is_exception') == 1,
                    isRestricted: row.read<int>('is_restricted') == 1,
                    isOtc: row.read<int>('is_otc') == 1,
                    smrNiveau: row.read<String?>('smr_niveau'),
                    smrDate: row.read<String?>('smr_date'),
                    asmrNiveau: row.read<String?>('asmr_niveau'),
                    asmrDate: row.read<String?>('asmr_date'),
                    urlNotice: row.read<String?>('url_notice'),
                    hasSafetyAlert: row.read<int?>('has_safety_alert') == 1,
                  ),
                ),
              )
              .toList(),
        );
  }

  Future<List<GroupDetailEntity>> getGroupDetails(
    String groupId,
  ) async {
    LoggerService.db(
      'Fetching snapshot for group $groupId via view_cluster_variants',
    );

    final rows = await customSelect(
      '''
      SELECT
        vcv.cluster_id,
        vcv.cis_code,
        vcv.label,
        vcv.dosage,
        vcv.form,
        vcv.is_princeps,
        vcv.routes,
        vcv.is_otc,
        vcv.default_cip,
        vcv.prix_public,
        ms.group_id,
        ms.princeps_de_reference,
        ms.princeps_brand_name,
        ms.status,
        ms.forme_pharmaceutique,
        ms.voies_administration,
        ms.principes_actifs_communs,
        ms.formatted_dosage,
        ls.name AS summary_titulaire,
        ms.procedure_type,
        ms.conditions_prescription,
        ms.is_surveillance,
        ms.atc_code,
        ms.member_type,
        ms.ansm_alert_url,
        ms.is_hospital AS is_hospital_only,
        ms.is_dental,
        ms.is_list1,
        ms.is_list2,
        ms.is_narcotic,
        ms.is_exception,
        ms.is_restricted,
        ms.is_otc,
        ms.smr_niveau,
        ms.smr_date,
        ms.asmr_niveau,
        ms.asmr_date,
        ms.url_notice,
        ms.has_safety_alert
      FROM view_cluster_variants vcv
      JOIN medicament_summary ms ON ms.cis_code = vcv.cis_code
      LEFT JOIN laboratories ls ON ls.id = ms.titulaire_id
      WHERE vcv.cluster_id = ?
      ORDER BY vcv.is_princeps DESC, vcv.label
    ''',
      variables: [Variable<String>(groupId)],
      readsFrom: {},
    ).get();

    return rows
        .map(
          (row) => GroupDetailEntity.fromData(
            ViewGroupDetail(
              groupId: row.read<String>('group_id'),
              codeCip: row.read<String>('default_cip'),
              rawLabel: row.read<String?>('label'),
              princepsCisReference: row.read<String?>('cis_code'),
              cisCode: row.read<String>('cis_code'),
              nomCanonique: row.read<String>('label'),
              princepsDeReference: row.read<String>('princeps_de_reference'),
              princepsBrandName: row.read<String>('princeps_brand_name'),
              isPrinceps: row.read<int>('is_princeps') == 1,
              status: row.read<String?>('status'),
              formePharmaceutique: row.read<String?>('form'),
              voiesAdministration: row.read<String?>('routes'),
              principesActifsCommuns: row.read<String?>(
                'principes_actifs_communs',
              ),
              formattedDosage: row.read<String?>('dosage'),
              summaryTitulaire: row.read<String?>('summary_titulaire'),
              officialTitulaire: row.read<String?>('summary_titulaire'),
              nomSpecialite: row.read<String>('label'),
              procedureType: row.read<String?>('procedure_type'),
              conditionsPrescription: row.read<String?>(
                'conditions_prescription',
              ),
              isSurveillance: row.read<int>('is_surveillance') == 1,
              atcCode: row.read<String?>('atc_code'),
              memberType: row.read<int>('member_type'),
              prixPublic: row.read<num?>('prix_public')?.toDouble(),
              ansmAlertUrl: row.read<String?>('ansm_alert_url'),
              isHospitalOnly: row.read<int>('is_hospital_only') == 1,
              isDental: row.read<int>('is_dental') == 1,
              isList1: row.read<int>('is_list1') == 1,
              isList2: row.read<int>('is_list2') == 1,
              isNarcotic: row.read<int>('is_narcotic') == 1,
              isException: row.read<int>('is_exception') == 1,
              isRestricted: row.read<int>('is_restricted') == 1,
              isOtc: row.read<int>('is_otc') == 1,
              smrNiveau: row.read<String?>('smr_niveau'),
              smrDate: row.read<String?>('smr_date'),
              asmrNiveau: row.read<String?>('asmr_niveau'),
              asmrDate: row.read<String?>('asmr_date'),
              urlNotice: row.read<String?>('url_notice'),
              hasSafetyAlert: row.read<int?>('has_safety_alert') == 1,
            ),
          ),
        )
        .toList();
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
      '''
      SELECT
        vel.cluster_id,
        vel.title,
        vel.subtitle,
        vel.secondary_princeps,
        vel.is_narcotic,
        vel.variant_count,
        vel.representative_cis,
        ms.princeps_de_reference,
        ms.principes_actifs_communs
      FROM view_explorer_list vel
      JOIN medicament_summary ms ON ms.cluster_id = vel.cluster_id
      WHERE ms.principes_actifs_communs IS NOT NULL
        AND ms.principes_actifs_communs != '[]'
        AND ms.principes_actifs_communs != ''
      ORDER BY vel.title
      LIMIT ? OFFSET ?
    ''',
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
      '''
      SELECT DISTINCT procedure_type
      FROM medicament_summary
      WHERE procedure_type IS NOT NULL AND procedure_type != ''
      ORDER BY procedure_type
      ''',
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
      '''
      SELECT DISTINCT voies_administration
      FROM medicament_summary
      WHERE voies_administration IS NOT NULL AND voies_administration != ''
      ORDER BY voies_administration
      ''',
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
