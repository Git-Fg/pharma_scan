import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/features/explorer/models/grouped_by_product_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_classification_provider.g.dart';

@riverpod
Stream<GroupedProductsViewModel> groupDetailViewModel(Ref ref, String groupId) {
  final libraryDao = ref.watch(libraryDaoProvider);
  return libraryDao
      .watchGroupDetails(groupId)
      .map(buildGroupedProductsViewModel);
}

@riverpod
Future<List<RelatedPrincepsItem>> relatedPrinceps(
  Ref ref,
  String groupId,
) async {
  final libraryDao = ref.watch(libraryDaoProvider);
  final related = await libraryDao.fetchRelatedPrinceps(groupId);
  return related.map(RelatedPrincepsItem.fromGroupDetail).toList();
}
