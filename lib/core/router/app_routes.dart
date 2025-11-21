// lib/core/router/app_routes.dart
class AppRoutes {
  AppRoutes._();

  // Root paths
  static const scanner = '/scanner';
  static const explorer = '/explorer';
  static const settings = '/settings';
  static const logs = '/logs';

  // Path parameter identifiers
  static const pidGroup = 'groupId';
  static const pidCluster = 'clusterKey';

  // Relative paths for GoRouter configuration
  static const groupDetailPath = 'group/:$pidGroup';
  static const clusterDetailPath = 'cluster/:$pidCluster';

  // Computed navigation targets
  static String groupDetail(String groupId) => '$explorer/group/$groupId';

  static String clusterDetail(
    String clusterKey, {
    required String brandName,
    required List<String> activeIngredients,
  }) {
    final encodedBrand = Uri.encodeComponent(brandName);
    final encodedIngredients = Uri.encodeComponent(activeIngredients.join(','));
    return '$explorer/cluster/$clusterKey'
        '?princepsBrandName=$encodedBrand'
        '&activeIngredients=$encodedIngredients';
  }
}
