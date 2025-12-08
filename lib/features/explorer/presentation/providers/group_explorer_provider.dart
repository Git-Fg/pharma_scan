import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/view_group_detail_extensions.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/group_explorer_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_explorer_provider.g.dart';

@riverpod
class GroupExplorerController extends _$GroupExplorerController {
  @override
  Future<GroupExplorerState> build(String groupId) async {
    final catalogDao = ref.watch(catalogDaoProvider);

    final membersStream = catalogDao.watchGroupDetails(groupId);
    final members = (await membersStream.first)
        .map(GroupDetailEntity.fromData)
        .toList();

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
    final refundLabel =
        members.buildRefundLabel() ?? Strings.refundNotAvailable;
    final princepsCisCode = members.extractPrincepsCisCode();
    final ansmAlertUrl = members.extractAnsmAlertUrl();
    final firstMember = members.isNotEmpty ? members.first : null;

    return GroupExplorerState(
      title: metadata.title,
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
      princepsCisReference:
          firstMember?.princepsCisReference ?? princepsCisCode,
    );
  }
}
