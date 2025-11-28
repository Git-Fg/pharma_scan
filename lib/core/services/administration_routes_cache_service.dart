// lib/core/services/administration_routes_cache_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

/// WHY: Persistent cache service for administration routes to avoid
/// expensive database queries on app startup and between sessions.
class AdministrationRoutesCacheService {
  static const String _cacheFileName = 'administration_routes_cache.json';

  /// Loads cached routes from persistent storage
  Future<List<String>?> loadCache() async {
    try {
      final file = await _getCacheFile();
      if (!await file.exists()) {
        LoggerService.info('[RoutesCache] No cache file found');
        return null;
      }

      final content = await file.readAsString();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final routes = (decoded['routes'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();

      if (routes == null || routes.isEmpty) {
        LoggerService.warning('[RoutesCache] Cache file is empty or invalid');
        return null;
      }

      LoggerService.info(
        '[RoutesCache] Loaded ${routes.length} routes from cache',
      );
      return routes;
    } catch (error, stackTrace) {
      LoggerService.error(
        '[RoutesCache] Failed to load cache: $error',
        error,
        stackTrace,
      );
      return null;
    }
  }

  /// Saves routes to persistent cache
  Future<void> saveCache(List<String> routes) async {
    try {
      final file = await _getCacheFile();
      final data = {
        'routes': routes,
        'cachedAt': DateTime.now().toIso8601String(),
        'version': 1, // For future cache invalidation if schema changes
      };
      final content = jsonEncode(data);
      await file.writeAsString(content, flush: true);
      LoggerService.info(
        '[RoutesCache] Saved ${routes.length} routes to cache',
      );
    } catch (error, stackTrace) {
      LoggerService.error(
        '[RoutesCache] Failed to save cache: $error',
        error,
        stackTrace,
      );
    }
  }

  /// Clears the cache file
  Future<void> clearCache() async {
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        await file.delete();
        LoggerService.info('[RoutesCache] Cache cleared');
      }
    } catch (error, stackTrace) {
      LoggerService.error(
        '[RoutesCache] Failed to clear cache: $error',
        error,
        stackTrace,
      );
    }
  }

  Future<File> _getCacheFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_cacheFileName');
  }
}
