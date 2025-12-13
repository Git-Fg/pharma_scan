import 'dart:convert';

import 'package:pharma_scan/core/database/dbschema.drift.dart';
import 'package:pharma_scan/core/database/views.drift.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';

/// Extension on [ViewSearchResult] to directly convert to search items
/// without intermediate mapping through MedicamentSummaryData.
extension ViewSearchResultExtension on ViewSearchResult {
  /// Converts this ViewSearchResult to a SearchResultItem
  SearchResultItem? toSearchResultItem() {
    switch (type) {
      case 'cluster':
        return _toClusterResult();
      case 'group':
        return _toGroupResult();
      case 'standalone':
        return _toStandaloneResult();
      default:
        return null;
    }
  }

  ClusterResult _toClusterResult() {
    final groups = _parseGroups(groupsJson);
    final displayName = _nonEmpty(commonPrincipes, fallback: Strings.notDetermined);
    final sortKey = _nonEmpty(this.sortKey, fallback: Strings.notDetermined);

    return ClusterResult(
      groups: groups,
      displayName: displayName,
      commonPrincipes: displayName,
      sortKey: sortKey,
    );
  }

  GroupResult _toGroupResult() {
    final commonPrincipes = _nonEmpty(this.commonPrincipes, fallback: Strings.notDetermined);
    final princepsRefName = _nonEmpty(princepsReferenceName, fallback: Strings.notDetermined);

    return GroupResult(
      group: GenericGroupEntity(
        groupId: GroupId(groupId!),
        commonPrincipes: commonPrincipes,
        princepsReferenceName: princepsRefName,
        princepsCisCode: princepsCisCode != null ? CisCode(princepsCisCode!) : null,
      ),
    );
  }

  StandaloneResult? _toStandaloneResult() {
    if (cisCode == null) return null;

    final principlesList = _decodePrinciples(principesActifsCommuns);
    final commonPrinciples = principlesList
        .where((p) => p.trim().isNotEmpty)
        .join(', ');

    // Create MedicamentSummaryData directly from ViewSearchResult fields
    final summary = MedicamentSummaryData(
      cisCode: cisCode!,
      nomCanonique: nomCanonique ?? '',
      princepsDeReference: princepsDeReference ?? '',
      isPrinceps: isPrinceps ?? false,
      groupId: groupId,
      principesActifsCommuns: principesActifsCommuns != null && principesActifsCommuns!.isNotEmpty
          ? principesActifsCommuns!
          : null,
      formattedDosage: formattedDosage,
      formePharmaceutique: formePharmaceutique,
      voiesAdministration: voiesAdministration,
      memberType: memberType ?? 0,
      princepsBrandName: princepsBrandName ?? '',
      procedureType: procedureType,
      titulaireId: titulaireId,
      conditionsPrescription: conditionsPrescription,
      dateAmm: dateAmm,
      isSurveillance: isSurveillance ?? false,
      atcCode: atcCode,
      status: status,
      priceMin: priceMin,
      priceMax: priceMax,
      aggregatedConditions: aggregatedConditions,
      ansmAlertUrl: ansmAlertUrl,
      isHospital: isHospital ?? false,
      isDental: isDental ?? false,
      isList1: isList1 ?? false,
      isList2: isList2 ?? false,
      isNarcotic: isNarcotic ?? false,
      isException: isException ?? false,
      isRestricted: isRestricted ?? false,
      isOtc: isOtc ?? false,
      representativeCip: representativeCip,
    );

    final entity = MedicamentEntity.fromData(summary, labName: labName);
    final repCip = Cip13.validated(
      representativeCip ?? cisCode ?? '',
    );

    return StandaloneResult(
      cisCode: entity.cisCode,
      summary: entity,
      representativeCip: repCip,
      commonPrinciples: commonPrinciples.isNotEmpty
          ? commonPrinciples
          : Strings.notDetermined,
    );
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

  List<String> _decodePrinciples(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
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
}
