// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/core/router/routes.dart';

part 'app_router.g.dart';

// Private keys to maintain control over the navigator state
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

@riverpod
GoRouter goRouter(Ref ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.scanner,
    debugLogDiagnostics: true,
    routes: $appRoutes,
  );
}
