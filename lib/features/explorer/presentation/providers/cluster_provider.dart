import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';

/// Provider that watches cluster search results
final clusterSearchProvider =
    StreamProvider.family.autoDispose<List<ClusterIndexData>, String>(
  (ref, query) async* {
    final db = ref.watch(databaseProvider());
    await for (final clusters in db.explorerDao.watchClusters(query)) {
      yield clusters;
    }
  },
);

/// Provider that gets cluster content (lazy loaded)
final clusterContentProvider =
    FutureProvider.family.autoDispose<List<MedicamentDetailData>, String>(
  (ref, clusterId) async {
    final db = ref.watch(databaseProvider());
    return db.explorerDao.getClusterContent(clusterId);
  },
);
