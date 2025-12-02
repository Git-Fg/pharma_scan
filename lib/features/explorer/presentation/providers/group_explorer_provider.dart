import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/utils/strings.dart';
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
    final members = await membersStream.first;

    final relatedMembers = await catalogDao.fetchRelatedPrinceps(groupId);

    if (members.isEmpty) {
      // Return empty state if no members
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

    // Perform all transformations
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
    );
  }
}
