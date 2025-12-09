import 'dart:async';

import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/view_group_detail_extensions.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/group_explorer_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_explorer_provider.g.dart';

@riverpod
Future<GroupExplorerState> groupExplorer(
  Ref ref,
  String groupId,
) async {
  final catalogDao = ref.watch(catalogDaoProvider);

  final membersStream = catalogDao.watchGroupDetails(groupId);
  final membersRaw = await _firstNonEmpty(membersStream);
  final members = membersRaw.map(GroupDetailEntity.fromData).toList();

  final relatedMembers = (await catalogDao.fetchRelatedPrinceps(
    groupId,
  )).map(GroupDetailEntity.fromData).toList();

  if (members.isEmpty) {
    return const GroupExplorerState(
      title: '',
      princeps: [],
      generics: [],
      related: [],
      commonPrincipes: [],
      distinctDosages: [],
      distinctForms: [],
      aggregatedConditions: [],
      priceLabel: Strings.priceUnavailable,
      refundLabel: Strings.refundNotAvailable,
    );
  }

  final metadata = members.toGroupHeaderMetadata();
  final partitioned = members.partitionByPrinceps();
  final princepsMembers = partitioned.princeps.sortedBySmartComparator();
  final genericMembers = partitioned.generics.sortedBySmartComparator();
  final aggregatedConditions = members.aggregateConditions();
  final priceLabel = members.buildPriceLabel() ?? Strings.priceUnavailable;
  final refundLabel = members.buildRefundLabel() ?? Strings.refundNotAvailable;
  final princepsCisCode = members.extractPrincepsCisCode();
  final ansmAlertUrl = members.extractAnsmAlertUrl();
  final firstMember = members.isNotEmpty ? members.first : null;
  final displayTitle = princepsMembers.isNotEmpty
      ? _buildPrincepsDisplayTitle(princepsMembers.first)
      : metadata.title;

  return GroupExplorerState(
    title: displayTitle,
    princeps: princepsMembers,
    generics: genericMembers,
    related: relatedMembers,
    commonPrincipes: metadata.commonPrincipes,
    distinctDosages: metadata.distinctDosages,
    distinctForms: metadata.distinctFormulations,
    aggregatedConditions: aggregatedConditions,
    priceLabel: priceLabel,
    refundLabel: refundLabel,
    ansmAlertUrl: ansmAlertUrl,
    princepsCisCode: princepsCisCode,
    rawLabelAnsm: firstMember?.rawLabel,
    parsingMethod: firstMember?.parsingMethod,
    princepsCisReference: firstMember?.princepsCisReference ?? princepsCisCode,
  );
}

Future<List<T>> _firstNonEmpty<T>(Stream<List<T>> stream) async {
  try {
    return await stream
        .firstWhere((items) => items.isNotEmpty)
        .timeout(const Duration(seconds: 5));
  } on TimeoutException {
    return stream.first;
  }
}

String _buildPrincepsDisplayTitle(GroupDetailEntity princeps) {
  final brand = princeps.princepsBrandName.trim();
  if (brand.isNotEmpty) {
    return extractPrincepsLabel(brand);
  }

  final nomSpecialite = princeps.nomSpecialite.trim();
  if (nomSpecialite.isNotEmpty) {
    return extractPrincepsLabel(nomSpecialite);
  }

  return extractPrincepsLabel(princeps.princepsDeReference);
}
