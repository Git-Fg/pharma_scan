import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pharma_scan/core/providers/repositories_providers.dart';

part 'database_stats_provider.g.dart';

@riverpod
Future<Map<String, dynamic>> databaseStats(Ref ref) async {
  final repository = ref.watch(explorerRepositoryProvider);
  return repository.getDatabaseStats();
}
