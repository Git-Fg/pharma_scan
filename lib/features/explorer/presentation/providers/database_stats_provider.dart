import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_stats_provider.g.dart';

@riverpod
Future<Map<String, dynamic>> databaseStats(Ref ref) async {
  final catalogDao = ref.watch(catalogDaoProvider);
  return catalogDao.getDatabaseStats();
}
