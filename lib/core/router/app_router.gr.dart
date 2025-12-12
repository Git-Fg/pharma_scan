// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [CameraScreen]
class ScannerRoute extends PageRouteInfo<void> {
  const ScannerRoute({List<PageRouteInfo>? children})
      : super(ScannerRoute.name, initialChildren: children);

  static const String name = 'ScannerRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const CameraScreen();
    },
  );
}

/// generated route for
/// [DatabaseScreen]
class DatabaseRoute extends PageRouteInfo<void> {
  const DatabaseRoute({List<PageRouteInfo>? children})
      : super(DatabaseRoute.name, initialChildren: children);

  static const String name = 'DatabaseRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const DatabaseScreen();
    },
  );
}

/// generated route for
/// [ExplorerTabScreen]
class ExplorerTabRoute extends PageRouteInfo<void> {
  const ExplorerTabRoute({List<PageRouteInfo>? children})
      : super(ExplorerTabRoute.name, initialChildren: children);

  static const String name = 'ExplorerTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ExplorerTabScreen();
    },
  );
}

/// generated route for
/// [GroupExplorerView]
class GroupExplorerRoute extends PageRouteInfo<GroupExplorerRouteArgs> {
  GroupExplorerRoute({
    required String groupId,
    Key? key,
    List<PageRouteInfo>? children,
  }) : super(
          GroupExplorerRoute.name,
          args: GroupExplorerRouteArgs(groupId: groupId, key: key),
          rawPathParams: {'groupId': groupId},
          initialChildren: children,
        );

  static const String name = 'GroupExplorerRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<GroupExplorerRouteArgs>(
        orElse: () =>
            GroupExplorerRouteArgs(groupId: pathParams.getString('groupId')),
      );
      return GroupExplorerView(groupId: args.groupId, key: args.key);
    },
  );
}

class GroupExplorerRouteArgs {
  const GroupExplorerRouteArgs({required this.groupId, this.key});

  final String groupId;

  final Key? key;

  @override
  String toString() {
    return 'GroupExplorerRouteArgs{groupId: $groupId, key: $key}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GroupExplorerRouteArgs) return false;
    return groupId == other.groupId && key == other.key;
  }

  @override
  int get hashCode => groupId.hashCode ^ key.hashCode;
}

/// generated route for
/// [LogsScreenWrapper]
class LogsRoute extends PageRouteInfo<void> {
  const LogsRoute({List<PageRouteInfo>? children})
      : super(LogsRoute.name, initialChildren: children);

  static const String name = 'LogsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const LogsScreenWrapper();
    },
  );
}

/// generated route for
/// [MainScreen]
class MainRoute extends PageRouteInfo<void> {
  const MainRoute({List<PageRouteInfo>? children})
      : super(MainRoute.name, initialChildren: children);

  static const String name = 'MainRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const MainScreen();
    },
  );
}

/// generated route for
/// [RestockScreen]
class RestockRoute extends PageRouteInfo<void> {
  const RestockRoute({List<PageRouteInfo>? children})
      : super(RestockRoute.name, initialChildren: children);

  static const String name = 'RestockRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const RestockScreen();
    },
  );
}

/// generated route for
/// [ScannerTabScreen]
class ScannerTabRoute extends PageRouteInfo<void> {
  const ScannerTabRoute({List<PageRouteInfo>? children})
      : super(ScannerTabRoute.name, initialChildren: children);

  static const String name = 'ScannerTabRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ScannerTabScreen();
    },
  );
}

/// generated route for
/// [SettingsScreen]
class SettingsRoute extends PageRouteInfo<void> {
  const SettingsRoute({List<PageRouteInfo>? children})
      : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SettingsScreen();
    },
  );
}
