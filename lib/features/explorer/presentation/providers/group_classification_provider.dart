import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_classification_provider.g.dart';

/// Simple alias so riverpod_generator accepts Drift's generated list type.
typedef GroupDetailsList = List<ViewGroupDetail>;

@riverpod
Stream<GroupDetailsList> groupDetailViewModel(Ref ref, String groupId) {
  final catalogDao = ref.watch(catalogDaoProvider);
  return catalogDao.watchGroupDetails(groupId);
}

@riverpod
Future<GroupDetailsList> relatedPrinceps(
  Ref ref,
  String groupId,
) async {
  final catalogDao = ref.watch(catalogDaoProvider);
  return catalogDao.fetchRelatedPrinceps(groupId);
}
