import 'dart:async';
import 'dart:convert';

import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/queries.drift.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_provider.g.dart';

@riverpod
class SearchFiltersNotifier extends _$SearchFiltersNotifier {
  @override
  SearchFilters build() => const SearchFilters(
    voieAdministration: 'orale',
  );

  SearchFilters get filters => state;

  set filters(SearchFilters filters) => state = filters;

  void clearFilters() {
    state = const SearchFilters();
  }
}

@riverpod
Stream<List<SearchResultItem>> searchResults(Ref ref, String rawQuery) {
  final query = rawQuery.trim();
  if (query.isEmpty) {
    return Stream<List<SearchResultItem>>.value(const <SearchResultItem>[]);
  }
  final normalizedQuery = NormalizedQuery.fromString(query);

  final catalogDao = ref.watch(catalogDaoProvider);
  return catalogDao.watchSearchResultsSql(normalizedQuery).map((rows) {
    if (rows.isEmpty) return const <SearchResultItem>[];
    return rows.map(_mapSearchRowToItem).whereType<SearchResultItem>().toList();
  });
}

SearchResultItem? _mapSearchRowToItem(SearchResultsResult row) {
  switch (row.type) {
    case 'cluster':
      final groups = _parseGroups(row.groupsJson);
      final displayName = _nonEmpty(
        row.commonPrincipes,
        fallback: Strings.notDetermined,
      );
      final sortKey = _nonEmpty(row.sortKey, fallback: Strings.notDetermined);
      return ClusterResult(
        groups: groups,
        displayName: displayName,
        commonPrincipes: displayName,
        sortKey: sortKey,
      );
    case 'group':
      final commonPrincipes = _nonEmpty(
        row.commonPrincipes,
        fallback: Strings.notDetermined,
      );
      final princepsReferenceName = _nonEmpty(
        row.princepsReferenceName,
        fallback: Strings.notDetermined,
      );
      return GroupResult(
        group: GenericGroupEntity(
          groupId: GroupId(row.groupId!),
          commonPrincipes: commonPrincipes,
          princepsReferenceName: princepsReferenceName,
          princepsCisCode: row.princepsCisCode != null
              ? CisCode(row.princepsCisCode!)
              : null,
        ),
      );
    case 'standalone':
      if (row.cisCode == null) return null;
      final principlesList = _decodePrinciples(row.principesActifsCommuns);
      final summary = MedicamentSummaryData(
        cisCode: row.cisCode!,
        nomCanonique: row.nomCanonique ?? '',
        isPrinceps: row.isPrinceps ?? false,
        groupId: row.groupId,
        memberType: row.memberType ?? 0,
        principesActifsCommuns: principlesList,
        princepsDeReference: row.princepsDeReference ?? '',
        formePharmaceutique: row.formePharmaceutique,
        voiesAdministration: row.voiesAdministration,
        princepsBrandName: row.princepsBrandName ?? '',
        procedureType: row.procedureType,
        titulaireId: row.titulaireId,
        conditionsPrescription: row.conditionsPrescription,
        dateAmm: row.dateAmm,
        isSurveillance: row.isSurveillance ?? false,
        formattedDosage: row.formattedDosage,
        atcCode: row.atcCode,
        status: row.status,
        priceMin: row.priceMin,
        priceMax: row.priceMax,
        aggregatedConditions: row.aggregatedConditions,
        ansmAlertUrl: row.ansmAlertUrl,
        isHospitalOnly: row.isHospital ?? false,
        isDental: row.isDental ?? false,
        isList1: row.isList1 ?? false,
        isList2: row.isList2 ?? false,
        isNarcotic: row.isNarcotic ?? false,
        isException: row.isException ?? false,
        isRestricted: row.isRestricted ?? false,
        isOtc: row.isOtc ?? false,
        representativeCip: row.representativeCip,
      );
      final entity = MedicamentEntity.fromData(
        summary,
        labName: row.labName,
      );

      final commonPrinciples = principlesList
          .map(normalizePrincipleOptimal)
          .where((p) => p.isNotEmpty)
          .join(', ');
      final representativeCip = Cip13.validated(
        row.representativeCip ?? row.cisCode!,
      );

      return StandaloneResult(
        cisCode: entity.cisCode,
        summary: entity,
        representativeCip: representativeCip,
        commonPrinciples: commonPrinciples.isNotEmpty
            ? commonPrinciples
            : Strings.notDetermined,
      );
    default:
      return null;
  }
}

List<GenericGroupEntity> _parseGroups(String? groupsJson) {
  if (groupsJson == null || groupsJson.isEmpty) {
    return const <GenericGroupEntity>[];
  }
  try {
    final decoded = jsonDecode(groupsJson) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => GenericGroupEntity(
            groupId: GroupId(item['group_id'] as String),
            commonPrincipes: _nonEmpty(
              item['common_principes'] as String?,
              fallback: Strings.notDetermined,
            ),
            princepsReferenceName: _nonEmpty(
              item['princeps_reference_name'] as String?,
              fallback: Strings.notDetermined,
            ),
            princepsCisCode: item['princeps_cis_code'] != null
                ? CisCode(item['princeps_cis_code'] as String)
                : null,
          ),
        )
        .toList();
  } on Exception {
    return const <GenericGroupEntity>[];
  }
}

String _nonEmpty(String? value, {required String fallback}) {
  if (value == null) return fallback;
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

List<String> _decodePrinciples(String raw) {
  if (raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .whereType<String>()
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
    }
  } on Exception {
    // ignore parse errors, return empty
  }
  return const [];
}
