import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/providers.dart';
import 'package:pharma_scan/core/network/dio_provider.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// Export databaseProvider pour faciliter les imports
export 'package:pharma_scan/core/database/providers.dart' show databaseProvider;
export 'package:pharma_scan/core/services/logger_service.dart'
    show loggerProvider;
export 'package:pharma_scan/core/services/haptic_service.dart'
    show hapticServiceProvider;
export 'app_settings_provider.dart';
import 'app_settings_provider.dart';

part 'core_providers.g.dart';

@Riverpod(keepAlive: true)
FileDownloadService fileDownloadService(Ref ref) {
  final dio = ref.watch(downloadDioProvider);
  final logger = ref.watch(loggerProvider);
  return FileDownloadService(dio: dio, talker: logger.talker);
}

@Riverpod(keepAlive: true)
DataInitializationService dataInitializationService(Ref ref) {
  final fileDownloadService = ref.watch(fileDownloadServiceProvider);
  final dio = ref.watch(dioProvider);

  return DataInitializationService(
    ref: ref,
    fileDownloadService: fileDownloadService,
    dio: dio,
  );
}

@riverpod
Future<int?> lastSyncEpoch(Ref ref) {
  return ref.read(appSettingsDaoProvider).lastSyncEpoch;
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
