import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/features/explorer/domain/models/grouped_by_product_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_classification_provider.g.dart';

@riverpod
Stream<GroupedProductsViewModel> groupDetailViewModel(Ref ref, String groupId) {
  final libraryDao = ref.watch(libraryDaoProvider);
  return libraryDao.watchGroupDetails(groupId).map((either) {
    return either.fold(
      ifLeft: (failure) => throw failure,
      ifRight: buildGroupedProductsViewModel,
    );
  });
}

@riverpod
Future<List<RelatedPrincepsItem>> relatedPrinceps(
  Ref ref,
  String groupId,
) async {
  final libraryDao = ref.watch(libraryDaoProvider);
  final relatedEither = await libraryDao.fetchRelatedPrinceps(groupId);
  return relatedEither.fold(
    ifLeft: (failure) => throw failure,
    ifRight: (related) =>
        related.map(RelatedPrincepsItem.fromGroupDetail).toList(),
  );
}
