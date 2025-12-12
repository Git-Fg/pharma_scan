import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// Export databaseProvider pour faciliter les imports
export 'package:pharma_scan/core/database/providers.dart' show databaseProvider;

part 'core_providers.g.dart';

@Riverpod(keepAlive: true)
FileDownloadService fileDownloadService(Ref ref) {
  return FileDownloadService();
}

@Riverpod(keepAlive: true)
DataInitializationService dataInitializationService(Ref ref) {
  final db = ref.watch(databaseProvider);
  final fileDownloadService = ref.watch(fileDownloadServiceProvider);
  final preferencesService = ref.watch(preferencesServiceProvider);

  return DataInitializationService(
    database: db,
    fileDownloadService: fileDownloadService,
    preferencesService: preferencesService,
  );
}

@riverpod
int? lastSyncEpoch(Ref ref) {
  final prefs = ref.watch(preferencesServiceProvider);
  return prefs.getInt(PrefKeys.lastSyncEpoch);
}

@Riverpod(keepAlive: true)
CatalogDao catalogDao(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.catalogDao;
}
