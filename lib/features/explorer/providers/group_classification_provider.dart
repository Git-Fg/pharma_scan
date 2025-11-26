import 'package:pharma_scan/core/database/daos/library_dao.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/features/explorer/models/grouped_products_view_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_classification_provider.g.dart';

@riverpod
Future<ProductGroupData?> rawGroupClassification(
  Ref ref,
  String groupId,
) async {
  final libraryDao = ref.watch(libraryDaoProvider);
  return libraryDao.classifyProductGroup(groupId);
}

@riverpod
Future<GroupedProductsViewModel?> groupDetailViewModel(
  Ref ref,
  String groupId,
) async {
  final groupData = await ref.watch(
    rawGroupClassificationProvider(groupId).future,
  );
  if (groupData == null) return null;
  return buildGroupedProductsViewModel(groupData);
}
