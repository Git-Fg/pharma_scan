import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/features/explorer/screens/database_screen.dart';
import 'package:pharma_scan/features/explorer/screens/group_explorer_view.dart';
import 'package:pharma_scan/features/home/screens/main_screen.dart';
import 'package:pharma_scan/features/scanner/screens/camera_screen.dart';
import 'package:pharma_scan/features/settings/screens/settings_screen.dart';
import 'package:talker_flutter/talker_flutter.dart';

part 'routes.g.dart';

@TypedStatefulShellRoute<MainShellRouteData>(
  branches: [
    TypedStatefulShellBranch<ScannerBranchData>(
      routes: [TypedGoRoute<ScannerRoute>(path: AppRoutes.scanner)],
    ),
    TypedStatefulShellBranch<ExplorerBranchData>(
      routes: [
        TypedGoRoute<ExplorerRoute>(
          path: AppRoutes.explorer,
          routes: [
            TypedGoRoute<GroupDetailRoute>(path: AppRoutes.groupDetailPath),
          ],
        ),
      ],
    ),
  ],
)
class MainShellRouteData extends StatefulShellRouteData {
  const MainShellRouteData();

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) {
    return MainScreen(navigationShell: navigationShell);
  }
}

class ScannerBranchData extends StatefulShellBranchData {
  const ScannerBranchData();
}

class ScannerRoute extends GoRouteData with $ScannerRoute {
  const ScannerRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const CameraScreen();
  }
}

class ExplorerBranchData extends StatefulShellBranchData {
  const ExplorerBranchData();
}

class ExplorerRoute extends GoRouteData with $ExplorerRoute {
  const ExplorerRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const DatabaseScreen();
  }
}

class GroupDetailRoute extends GoRouteData with $GroupDetailRoute {
  const GroupDetailRoute({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return GroupExplorerView(groupId: groupId);
  }
}

@TypedGoRoute<SettingsRoute>(path: AppRoutes.settings)
class SettingsRoute extends GoRouteData with $SettingsRoute {
  const SettingsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const SettingsScreen();
  }
}

@TypedGoRoute<LogsRoute>(path: AppRoutes.logs)
class LogsRoute extends GoRouteData with $LogsRoute {
  const LogsRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return TalkerScreen(
      talker: LoggerService().talker,
      theme: const TalkerScreenTheme(
        backgroundColor: Colors.black,
        textColor: Colors.white,
      ),
    );
  }
}
