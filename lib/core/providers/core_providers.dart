import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/daos/library_dao.dart';
import 'package:pharma_scan/core/database/daos/scan_dao.dart';
import 'package:pharma_scan/core/database/daos/search_dao.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'core_providers.g.dart';

// WHY: The Database is a singleton that lives as long as the app.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  return AppDatabase();
}

@Riverpod(keepAlive: true)
FileDownloadService fileDownloadService(Ref ref) {
  return FileDownloadService();
}

@Riverpod(keepAlive: true)
DataInitializationService dataInitializationService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final downloader = ref.watch(fileDownloadServiceProvider);

  return DataInitializationService(
    database: db,
    fileDownloadService: downloader,
  );
}

// WHY: Expose lastSyncEpoch as a stream so providers can reactively re-execute
// when sync completes. This eliminates the need for manual provider invalidation.
@riverpod
Stream<int?> lastSyncEpochStream(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.settingsDao.watchSettings().map(
    (settings) => settings.lastSyncEpoch,
  );
}

// WHY: Expose DAOs directly - no repository layer needed for read-only local viewer
@Riverpod(keepAlive: true)
ScanDao scanDao(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.scanDao;
}

@Riverpod(keepAlive: true)
SearchDao searchDao(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.searchDao;
}

@Riverpod(keepAlive: true)
LibraryDao libraryDao(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.libraryDao;
}
