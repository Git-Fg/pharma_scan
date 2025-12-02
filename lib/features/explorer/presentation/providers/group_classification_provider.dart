import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'group_classification_provider.g.dart';

/// Type alias workaround for riverpod_generator compatibility.
///
/// Riverpod Generator has issues recognizing complex generic types from
/// generated code (like Drift's ViewGroupDetail). Using `List<ViewGroupDetail>`
/// directly in `@riverpod` annotations causes `InvalidTypeException` during
/// code generation.
///
/// This typedef provides a simpler type reference that the generator can
/// process correctly, while maintaining the same runtime type semantics.
/// This is a documented workaround pattern for code generator compatibility
/// issues (similar to Freezed + Riverpod integration patterns).
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
