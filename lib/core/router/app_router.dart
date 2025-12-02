import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:pharma_scan/features/explorer/presentation/screens/database_screen.dart';
import 'package:pharma_scan/features/explorer/presentation/screens/group_explorer_view.dart';
import 'package:pharma_scan/features/home/screens/main_screen.dart';
import 'package:pharma_scan/features/scanner/presentation/screens/camera_screen.dart';
import 'package:pharma_scan/features/scanner/presentation/screens/scanner_tab_screen.dart';
import 'package:pharma_scan/features/settings/screens/logs_screen_wrapper.dart';
import 'package:pharma_scan/features/settings/screens/settings_screen.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen|Page|View,Route')
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
    // Main Shell (Bottom Nav)
    AutoRoute(
      page: MainRoute.page,
      initial: true,
      path: '/',
      children: [
        // Tab 1: Scanner (Stack imbriquée)
        AutoRoute(
          path: 'scanner',
          page: ScannerTabRoute.page, // Wrapper pour la stack
          children: [
            AutoRoute(path: '', page: ScannerRoute.page),
            AutoRoute(path: 'group/:groupId', page: GroupExplorerRoute.page),
          ],
        ),
        // Tab 2: Explorer (Stack imbriquée)
        AutoRoute(
          path: 'explorer',
          page: ExplorerTabRoute.page, // Wrapper pour la stack
          children: [
            AutoRoute(path: '', page: DatabaseRoute.page),
            AutoRoute(path: 'group/:groupId', page: GroupExplorerRoute.page),
          ],
        ),
      ],
    ),
    // Global Routes (Full screen)
    AutoRoute(path: '/settings', page: SettingsRoute.page),
    AutoRoute(path: '/logs', page: LogsRoute.page),
  ];
}

// Wrapper pour la navigation imbriquée dans l'onglet Explorer
@RoutePage(name: 'ExplorerTabRoute')
class ExplorerTabScreen extends AutoRouter {
  const ExplorerTabScreen({super.key});
}
