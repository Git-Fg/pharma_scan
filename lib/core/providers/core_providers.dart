import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/drift_database_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/sync_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'core_providers.g.dart';

// WHY: The Database is a singleton that lives as long as the app.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  return AppDatabase();
}

@Riverpod(keepAlive: true)
DriftDatabaseService driftDatabaseService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftDatabaseService(db);
}

@Riverpod(keepAlive: true)
FileDownloadService fileDownloadService(Ref ref) {
  return FileDownloadService();
}

@Riverpod(keepAlive: true)
DataInitializationService dataInitializationService(Ref ref) {
  final dbService = ref.watch(driftDatabaseServiceProvider);
  final downloader = ref.watch(fileDownloadServiceProvider);

  return DataInitializationService(
    databaseService: dbService,
    fileDownloadService: downloader,
  );
}

@Riverpod(keepAlive: true)
SyncService syncService(Ref ref) {
  final dataInit = ref.watch(dataInitializationServiceProvider);
  final db = ref.watch(driftDatabaseServiceProvider);
  final downloader = ref.watch(fileDownloadServiceProvider);

  return SyncService(
    databaseService: db,
    dataInitializationService: dataInit,
    fileDownloadService: downloader,
  );
}
