import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pharma_scan/core/providers/repositories_providers.dart';

part 'pharmaceutical_forms_provider.g.dart';

@riverpod
Future<List<String>> pharmaceuticalForms(Ref ref) async {
  final repository = ref.watch(explorerRepositoryProvider);
  return repository.getDistinctPharmaceuticalForms();
}
