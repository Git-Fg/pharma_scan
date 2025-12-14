import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/reference_schema.drift.dart';
import 'package:pharma_scan/core/utils/text_utils.dart';
import 'package:pharma_scan/features/explorer/domain/entities/cluster_entity.dart';

/// DAO for cluster-based search operations (Cluster-First Architecture)
///
/// This DAO handles:
/// 1. Fuzzy search using pre-computed search vectors
/// 2. Cluster-based results (concepts, not individual products)
/// 3. Lazy loading of cluster content (drawer content)
@DriftAccessor()
class ExplorerDao extends DatabaseAccessor<AppDatabase> {
  ExplorerDao(super.attachedDatabase);

  /// Search clusters using FTS5 with trigram tokenizer
  /// Returns clusters that match the query conceptually
  Stream<List<ClusterEntity>> watchClusters(String query) {
    if (query.isEmpty) return Stream.value([]);

    final cleanQuery = simpleNormalize(query);

    // Use customSelect with FTS5 MATCH for cluster-based search
    return customSelect(
      '''
      SELECT ci.*
      FROM cluster_index ci
      INNER JOIN search_index si ON si.cluster_id = ci.cluster_id
      WHERE search_index MATCH ?
      ORDER BY si.rowid
      LIMIT 50
      ''',
      variables: [Variable<String>(cleanQuery)],
      readsFrom: {attachedDatabase.clusterIndex, attachedDatabase.searchIndex},
    ).watch().map((rows) => rows
        .map((row) => ClusterEntity(ClusterIndexData(
              clusterId: row.read<String>('cluster_id'),
              title: row.read<String>('title'),
              subtitle: row.readNullable<String>('subtitle'),
              countProducts: row.readNullable<int>('count_products'),
              searchVector: row.readNullable<String>('search_vector'),
            )))
        .toList());
  }

  /// Get all products within a specific cluster (for drawer content)
  /// This is lazy-loaded when the user opens a cluster
  Future<List<ClusterProductEntity>> getClusterContent(String clusterId) {
    return customSelect(
      '''
      SELECT *
      FROM medicament_detail
      WHERE cluster_id = ?
      ORDER BY is_princeps DESC, nom_complet ASC
      ''',
      variables: [Variable<String>(clusterId)],
      readsFrom: {attachedDatabase.medicamentDetail},
    ).get().then((rows) => rows
        .map((row) => ClusterProductEntity(MedicamentDetailData(
              cisCode: row.read<String>('cis_code'),
              clusterId: row.readNullable<String>('cluster_id'),
              nomComplet: row.read<String>('nom_complet'),
              isPrinceps: row.read<int>('is_princeps'),
            )))
        .toList());
  }
}
