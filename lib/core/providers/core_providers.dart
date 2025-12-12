import 'dart:async';

import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/models/app_setting.dart';
import 'package:pharma_scan/core/database/providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/database_updater_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// Export databaseProvider pour faciliter les imports
export 'package:pharma_scan/core/database/providers.dart' show databaseProvider;

part 'core_providers.g.dart';

@Riverpod(keepAlive: true)
FileDownloadService fileDownloadService(Ref ref) {
  return FileDownloadService();
}

@Riverpod(keepAlive: true)
DatabaseUpdaterService databaseUpdaterService(Ref ref) {
  return DatabaseUpdaterService();
}

@Riverpod(keepAlive: true)
DataInitializationService dataInitializationService(Ref ref) {
  final db = ref.watch(databaseProvider);
  final fileDownloadService = ref.watch(fileDownloadServiceProvider);

  return DataInitializationService(
    database: db,
    fileDownloadService: fileDownloadService,
  );
}

@riverpod
Stream<int?> lastSyncEpochStream(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.settingsDao.watchSettings().map(
    (AppSetting settings) => settings.lastSyncEpoch,
  );
}

@Riverpod(keepAlive: true)
CatalogDao catalogDao(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.catalogDao;
}
