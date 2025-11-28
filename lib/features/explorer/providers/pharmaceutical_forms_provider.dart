import 'dart:async';

import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/administration_routes_cache_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pharmaceutical_forms_provider.g.dart';

@Riverpod(keepAlive: true)
Future<List<String>> administrationRoutes(Ref ref) async {
  // WHY: Watch sync timestamp - when data is synced, refresh cache
  // This ensures cache is updated after DB changes
  ref.watch(lastSyncEpochStreamProvider);

  final cacheService = AdministrationRoutesCacheService();
  final libraryDao = ref.watch(libraryDaoProvider);

  // WHY: Try to load from persistent cache first (instant, works offline)
  // This cache persists between app sessions for faster startup
  final cachedRoutes = await cacheService.loadCache();
  if (cachedRoutes != null && cachedRoutes.isNotEmpty) {
    // WHY: Refresh cache in background after sync, but return cached immediately
    // This provides instant UI load while ensuring cache stays up to date
    unawaited(
      libraryDao
          .getDistinctRoutes()
          .then((freshRoutes) async {
            if (freshRoutes.isNotEmpty) {
              await cacheService.saveCache(freshRoutes);
              // WHY: Invalidate provider to reload with fresh cached data
              ref.invalidateSelf();
            }
          })
          .catchError((error) {
            // Silently fail - cached data is still valid
          }),
    );
    return cachedRoutes;
  }

  // WHY: No cache available, load from database and persist for future sessions
  final routes = await libraryDao.getDistinctRoutes();
  if (routes.isNotEmpty) {
    await cacheService.saveCache(routes);
  }
  return routes;
}
