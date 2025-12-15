import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/domain/models/database_stats.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_stats_provider.g.dart';

@riverpod
Future<DatabaseStats> databaseStats(Ref ref) async {
  final catalogDao = ref.watch(catalogDaoProvider);
  return catalogDao.getDatabaseStats();
}
