// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/features/home/screens/main_screen.dart';
import 'package:pharma_scan/features/scanner/screens/camera_screen.dart';
import 'package:pharma_scan/features/explorer/screens/database_screen.dart';
import 'package:pharma_scan/features/explorer/screens/group_explorer_view.dart';
import 'package:pharma_scan/features/settings/screens/settings_screen.dart';

part 'app_router.g.dart';

// Private keys to maintain control over the navigator state
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _scannerNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'scanner');
final _explorerNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'explorer');

@riverpod
GoRouter goRouter(Ref ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.scanner,
    debugLogDiagnostics: true,
    routes: [
      // StatefulShellRoute preserves the state of each branch (tab)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          // MainScreen wraps the child navigation shell
          return MainScreen(navigationShell: navigationShell);
        },
        branches: [
          // BRANCH 0: Scanner
          StatefulShellBranch(
            navigatorKey: _scannerNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.scanner,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: CameraScreen()),
              ),
            ],
          ),
          // BRANCH 1: Explorer
          StatefulShellBranch(
            navigatorKey: _explorerNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.explorer,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: DatabaseScreen()),
                routes: [
                  // Detail view: Pushed ON TOP of the Explorer stack
                  // The bottom navigation bar remains visible.
                  GoRoute(
                    path: AppRoutes.groupDetailPath,
                    builder: (context, state) {
                      final groupId = state.pathParameters[AppRoutes.pidGroup]!;
                      return GroupExplorerView(groupId: groupId);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Settings route (root-level, not part of tab navigation)
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.logs,
        builder: (context, state) => TalkerScreen(
          talker: LoggerService().talker,
          theme: const TalkerScreenTheme(
            backgroundColor: Colors.black,
            textColor: Colors.white,
          ),
        ),
      ),
    ],
  );
}
