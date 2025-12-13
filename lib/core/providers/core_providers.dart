import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// Export databaseProvider pour faciliter les imports
export 'package:pharma_scan/core/database/providers.dart' show databaseProvider;
export 'package:pharma_scan/core/services/haptic_service.dart'
    show hapticServiceProvider;
export 'package:pharma_scan/core/services/preferences_service.dart'
    show preferencesServiceProvider;

part 'core_providers.g.dart';

@Riverpod(keepAlive: true)
FileDownloadService fileDownloadService(Ref ref) {
  return FileDownloadService();
}

@Riverpod(keepAlive: true)
DataInitializationService dataInitializationService(Ref ref) {
  // On ne watch PLUS la database ici pour éviter les boucles de reconstruction
  final fileDownloadService = ref.watch(fileDownloadServiceProvider);
  final preferencesService = ref.watch(preferencesServiceProvider);

  return DataInitializationService(
    ref: ref,
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
  final AppDatabase db = ref.read(databaseProvider());
  return db.catalogDao;
}

@Riverpod(keepAlive: true)
RestockDao restockDao(Ref ref) {
  final AppDatabase db = ref.read(databaseProvider());
  return db.restockDao;
}
