class AppRoutes {
  AppRoutes._();

  // Root paths
  static const scanner = '/scanner';
  static const explorer = '/explorer';
  static const settings = '/settings';
  static const logs = '/logs';

  // Path parameter identifiers
  static const pidGroup = 'groupId';

  // Relative paths for AutoRoute configuration
  static const groupDetailPath = 'group/:$pidGroup';

  // Computed navigation targets
  static String groupDetail(String groupId) => '$explorer/group/$groupId';
}
