import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/models/scan_result.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/database_stats.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';

part 'catalog_dao.g.dart';

typedef MedicamentSummaryWithLab = ({
  MedicamentSummaryData summary,
  String? labName,
});

extension MedicamentSummaryWithLabX on MedicamentSummaryWithLab {
  MedicamentSummaryData get data => summary;
  bool get isPrinceps => summary.isPrinceps;
  String? get groupId => summary.groupId;
  List<String> get principesActifsCommuns => summary.principesActifsCommuns;
  String get nomCanonique => summary.nomCanonique;
  String get princepsDeReference => summary.princepsDeReference;
  String get princepsBrandName => summary.princepsBrandName;
}

extension SearchMedicamentsResultX on SearchMedicamentsResult {
  MedicamentSummaryData toSummaryData() => MedicamentSummaryData(
    cisCode: cisCode,
    nomCanonique: nomCanonique,
    isPrinceps: isPrinceps,
    groupId: groupId,
    memberType: memberType,
    principesActifsCommuns: principesActifsCommuns,
    princepsDeReference: princepsDeReference,
    formePharmaceutique: formePharmaceutique,
    voiesAdministration: voiesAdministration,
    princepsBrandName: princepsBrandName,
    procedureType: procedureType,
    titulaireId: titulaireId,
    conditionsPrescription: conditionsPrescription,
    dateAmm: dateAmm,
    isSurveillance: isSurveillance,
    formattedDosage: formattedDosage,
    atcCode: atcCode,
    status: status,
    priceMin: priceMin,
    priceMax: priceMax,
    aggregatedConditions: aggregatedConditions,
    ansmAlertUrl: ansmAlertUrl,
    isHospitalOnly: isHospital,
    isDental: isDental,
    isList1: isList1,
    isList2: isList2,
    isNarcotic: isNarcotic,
    isException: isException,
    isRestricted: isRestricted,
    isOtc: isOtc,
    representativeCip: representativeCip,
  );

  MedicamentSummaryWithLab toSummaryWithLab() =>
      (summary: toSummaryData(), labName: labName);
}

/// Escapes a normalized query for FTS5 (lowercase, escape specials, join with AND).
String _buildFtsQuery(String raw) {
  final normalized = normalizeForSearch(raw).replaceAll('%', '');
  if (normalized.isEmpty) return '';
  final terms = normalized.split(' ').where((t) => t.isNotEmpty).toList();
  if (terms.isEmpty) return '';

  final parts = terms
      .map((term) => '{molecule_name brand_name} : "$term"')
      .toList();
  return parts.join(' AND ');
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
  Future<ScanResult?> getProductByCip(
    Cip13 codeCip, {
    DateTime? expDate,
  }) async {
    LoggerService.db('Lookup product for CIP $codeCip');

    final cipString = codeCip.toString();
    final query = select(medicaments).join([
      leftOuterJoin(
        medicamentAvailability,
        medicamentAvailability.codeCip.equalsExp(medicaments.codeCip),
      ),
    ])..where(medicaments.codeCip.equals(cipString));

    final row = await query.getSingleOrNull();

    if (row == null) {
      LoggerService.db('No medicament row found for CIP $cipString');
      return null;
    }

    final medicament = row.readTable(medicaments);
    final availabilityRow = row.readTableOrNull(medicamentAvailability);

    var summary =
        await (select(medicamentSummary)
              ..where((tbl) => tbl.cisCode.equals(medicament.cisCode)))
            .getSingleOrNull();
    String? labName;
    if (summary?.titulaireId != null) {
      final labRow =
          await (select(laboratories)
                ..where((tbl) => tbl.id.equals(summary!.titulaireId!)))
              .getSingleOrNull();
      labName = labRow?.name;
    }

    if (summary == null) {
      LoggerService.warning(
        '[CatalogDao] No medicament_summary row found for CIS ${medicament.cisCode}',
      );

      final specialite =
          await (select(specialites)
                ..where((tbl) => tbl.cisCode.equals(medicament.cisCode)))
              .getSingleOrNull();
      if (specialite == null) {
        return null;
      }
      if (specialite.titulaireId != null && labName == null) {
        final labRow =
            await (select(laboratories)
                  ..where((tbl) => tbl.id.equals(specialite.titulaireId!)))
                .getSingleOrNull();
        labName = labRow?.name;
      }

      final principleRows = await (select(
        principesActifs,
      )..where((tbl) => tbl.codeCip.equals(cipString))).get();
      final normalizedPrinciples = principleRows
          .map((p) => p.principeNormalized ?? p.principe)
          .where((p) => p.trim().isNotEmpty)
          .map((p) => p)
          .toList();

      final fallbackSummary = MedicamentSummaryData(
        cisCode: medicament.cisCode,
        nomCanonique: specialite.nomSpecialite,
        isPrinceps: true,
        memberType: 0,
        principesActifsCommuns: normalizedPrinciples,
        princepsDeReference: specialite.nomSpecialite,
        formePharmaceutique: specialite.formePharmaceutique,
        voiesAdministration: specialite.voiesAdministration,
        princepsBrandName: specialite.nomSpecialite,
        procedureType: specialite.procedureType,
        titulaireId: specialite.titulaireId,
        conditionsPrescription: specialite.conditionsPrescription,
        dateAmm: specialite.dateAmm,
        isSurveillance: specialite.isSurveillance,
        atcCode: specialite.atcCode,
        status: specialite.statutAdministratif,
        isHospitalOnly: false,
        isDental: false,
        isList1: false,
        isList2: false,
        isNarcotic: false,
        isException: false,
        isRestricted: false,
        isOtc: true,
        representativeCip: cipString,
      );

      await into(medicamentSummary).insertOnConflictUpdate(
        fallbackSummary.toCompanion(false),
      );
      summary = fallbackSummary;
    }

    final result = ScanResult(
      summary: MedicamentEntity.fromData(summary, labName: labName),
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
      expDate: expDate,
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

  Future<List<MedicamentSummaryWithLab>> searchMedicaments(
    NormalizedQuery query, {
    SearchFilters? filters,
  }) async {
    final sanitizedQuery = _buildFtsQuery(query.toString());
    if (sanitizedQuery.isEmpty) {
      LoggerService.db('Empty search query, returning empty results');
      return <MedicamentSummaryWithLab>[];
    }

    LoggerService.db(
      'Searching medicaments with FTS5 query: $sanitizedQuery',
    );

    final routeFilter = filters?.voieAdministration ?? '';
    final atcFilter = filters?.atcClass?.code ?? '';

    final labFilter = filters?.titulaireId ?? -1;
    final queryResults = await attachedDatabase
        .searchMedicaments(
          sanitizedQuery,
          routeFilter,
          atcFilter,
          labFilter,
        )
        .get();

    return queryResults.map((row) => row.toSummaryWithLab()).toList();
  }

  Stream<List<MedicamentSummaryWithLab>> watchMedicaments(
    NormalizedQuery query, {
    SearchFilters? filters,
  }) {
    final sanitizedQuery = _buildFtsQuery(query.toString());
    if (sanitizedQuery.isEmpty) {
      LoggerService.db('Empty search query, emitting empty stream');
      return Stream<List<MedicamentSummaryWithLab>>.value(
        const <MedicamentSummaryWithLab>[],
      );
    }

    LoggerService.db('Watching medicament search for query: $sanitizedQuery');

    final routeFilter = filters?.voieAdministration ?? '';
    final atcFilter = filters?.atcClass?.code ?? '';

    final labFilter = filters?.titulaireId ?? -1;

    return attachedDatabase
        .searchMedicaments(
          sanitizedQuery,
          routeFilter,
          atcFilter,
          labFilter,
        )
        .watch()
        .map((rows) => rows.map((row) => row.toSummaryWithLab()).toList());
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

  Future<DatabaseStats> getDatabaseStats() async {
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
    final tbl = attachedDatabase.viewGenericGroupSummaries;
    final filters = <Expression<bool>>[];

    if (procedureTypeKeywords != null && procedureTypeKeywords.isNotEmpty) {
      final procedureFilters = procedureTypeKeywords
          .map((kw) => tbl.procedureType.like('%$kw%'))
          .toList();
      filters.add(procedureFilters.reduce((a, b) => a | b));
    }

    if (atcClass != null && atcClass.isNotEmpty) {
      filters.add(tbl.atcCode.like('$atcClass%'));
    }

    if (routeKeywords != null && routeKeywords.isNotEmpty) {
      final routeFilters = routeKeywords
          .map((kw) => tbl.voiesAdministration.like('%$kw%'))
          .toList();
      filters.add(routeFilters.reduce((a, b) => a | b));
    } else if (formKeywords != null && formKeywords.isNotEmpty) {
      final formFilters = formKeywords
          .map((kw) => tbl.formePharmaceutique.like('%$kw%'))
          .toList();
      filters.add(formFilters.reduce((a, b) => a | b));

      if (excludeKeywords != null && excludeKeywords.isNotEmpty) {
        final excludeFilters = excludeKeywords
            .map((kw) => tbl.formePharmaceutique.like('%$kw%').not())
            .toList();
        filters.add(excludeFilters.reduce((a, b) => a & b));
      }
    }

    final query = select(tbl)
      ..orderBy([(t) => OrderingTerm.asc(t.princepsDeReference)])
      ..limit(limit, offset: offset);

    if (filters.isNotEmpty) {
      query.where((t) => filters.reduce((a, b) => a & b));
    }

    final rows = await query.get();

    final results = rows
        .map((row) {
          final groupId = row.groupId;
          if (groupId == null || groupId.isEmpty) return null;
          final rawPrincepsReference = row.princepsDeReference;
          if (rawPrincepsReference.isEmpty) {
            return null;
          }
          final princepsReference = extractPrincepsLabel(rawPrincepsReference);
          final commonPrincipes = row.commonPrincipes ?? '';

          if (commonPrincipes.trim().isEmpty || princepsReference.isEmpty) {
            return null;
          }

          final princepsCisCodeRaw = row.princepsCisCode;
          final princepsCisCode = princepsCisCodeRaw != null
              ? (princepsCisCodeRaw.length == 8
                    ? CisCode.validated(princepsCisCodeRaw)
                    : CisCode.unsafe(princepsCisCodeRaw))
              : null;

          return GenericGroupEntity(
            groupId: GroupId.validated(groupId),
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
