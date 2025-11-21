// lib/features/explorer/models/cluster_summary_model.dart

class ClusterSummary {
  const ClusterSummary({
    required this.clusterKey,
    required this.princepsBrandName,
    required this.activeIngredients,
    required this.groupCount,
    required this.memberCount,
  });

  final String clusterKey;
  final String princepsBrandName;
  final List<String> activeIngredients;
  final int groupCount;
  final int memberCount;
}
