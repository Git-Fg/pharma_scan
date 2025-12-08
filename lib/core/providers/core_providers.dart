import 'dart:async';

import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'core_providers.g.dart';

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

@riverpod
Stream<int?> lastSyncEpochStream(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.settingsDao.watchSettings().map(
    (AppSetting settings) => settings.lastSyncEpoch,
  );
}

@Riverpod(keepAlive: true)
CatalogDao catalogDao(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.catalogDao;
}
