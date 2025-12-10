import 'dart:async';

import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/tables/settings.drift.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_downloader.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_parser_service.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_repository.dart';
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
BdpmDownloader bdpmDownloader(Ref ref) {
  final downloader = ref.watch(fileDownloadServiceProvider);
  return BdpmDownloader(fileDownloadService: downloader);
}

@Riverpod(keepAlive: true)
BdpmParserService bdpmParserService(Ref ref) {
  return const BdpmParserService();
}

@Riverpod(keepAlive: true)
BdpmRepository bdpmRepository(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return BdpmRepository(db);
}

@Riverpod(keepAlive: true)
DataInitializationService dataInitializationService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final downloader = ref.watch(bdpmDownloaderProvider);
  final parserService = ref.watch(bdpmParserServiceProvider);
  final repository = ref.watch(bdpmRepositoryProvider);

  return DataInitializationService(
    database: db,
    downloader: downloader,
    parserService: parserService,
    repository: repository,
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
