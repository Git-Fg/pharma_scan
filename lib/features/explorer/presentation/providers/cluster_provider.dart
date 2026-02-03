import 'package:pharma_scan/core/domain/entities/cluster_entity.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cluster_provider.g.dart';

/// Provider that watches cluster search results
@riverpod
Stream<List<ClusterEntity>> clusterSearch(Ref ref, String query) async* {
  final db = ref.watch(databaseProvider());
  if (query.isEmpty) {
    await for (final clusters
        in db.explorerDao.watchAllClustersOrderedByPrinceps()) {
      yield clusters;
    }
  } else {
    await for (final clusters in db.explorerDao.watchClusters(query)) {
      yield clusters;
    }
  }
}

/// Provider that gets cluster content (lazy loaded)
@riverpod
Future<List<ClusterProductEntity>> clusterContent(
  Ref ref,
  String clusterId,
) async {
  final db = ref.watch(databaseProvider());
  return db.explorerDao.getClusterContent(clusterId);
}
