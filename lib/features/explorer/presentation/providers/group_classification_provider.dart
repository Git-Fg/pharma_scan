import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_classification_provider.g.dart';

/// Simple alias so riverpod_generator accepts Drift's generated list type.
typedef GroupDetailsList = List<GroupDetailEntity>;

@riverpod
Stream<GroupDetailsList> groupDetailViewModel(Ref ref, String groupId) {
  final catalogDao = ref.watch(catalogDaoProvider);
  return catalogDao
      .watchGroupDetails(groupId)
      .map((rows) => rows.map(GroupDetailEntity.fromData).toList());
}

@riverpod
Future<GroupDetailsList> relatedPrinceps(
  Ref ref,
  String groupId,
) async {
  final catalogDao = ref.watch(catalogDaoProvider);
  final rows = await catalogDao.fetchRelatedPrinceps(groupId);
  return rows.map(GroupDetailEntity.fromData).toList();
}
