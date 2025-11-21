import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pharma_scan/core/providers/repositories_providers.dart';
import 'package:pharma_scan/features/explorer/models/product_group_classification_model.dart';

part 'group_classification_provider.g.dart';

@riverpod
Future<ProductGroupClassification?> groupClassification(
  Ref ref,
  String groupId,
) async {
  final repository = ref.watch(explorerRepositoryProvider);
  return repository.classifyProductGroup(groupId);
}
