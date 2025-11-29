import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pharmaceutical_forms_provider.g.dart';

@Riverpod(keepAlive: true)
Future<List<String>> administrationRoutes(Ref ref) async {
  // WHY: Watch sync timestamp - when data is synced, refresh routes
  ref.watch(lastSyncEpochStreamProvider);

  final libraryDao = ref.watch(libraryDaoProvider);
  return libraryDao.getDistinctRoutes();
}
