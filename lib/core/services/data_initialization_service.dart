import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/config/data_sources.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/database_updater_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_downloader.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_parser_service.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_repository.dart';
import 'package:pharma_scan/core/services/ingestion/schema/file_validator.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';

typedef ParseDataArgs = ({
  Map<String, String> filePaths,
});

enum InitializationStep {
  idle,
  downloading,
  parsing,
  aggregating,
  ready,
  error,
}

class DataInitializationService {
  DataInitializationService({
    required AppDatabase database,
    BdpmDownloader? downloader,
    BdpmParserService? parserService,
    BdpmRepository? repository,
    String? cacheDirectory,
    FileDownloadService? fileDownloadService,
    DatabaseUpdaterService? databaseUpdaterService,
  }) : _db = database,
       _globalCacheDir = cacheDirectory ?? _resolveDefaultCacheDir(),
       _validator = BdpmFileValidator(),
       _downloader =
           downloader ??
           BdpmDownloader(
             fileDownloadService: fileDownloadService ?? FileDownloadService(),
             cacheDirectory: cacheDirectory ?? _resolveDefaultCacheDir(),
           ),
       _parserService = parserService ?? const BdpmParserService(),
       _repository = repository ?? BdpmRepository(database),
       _databaseUpdaterService = databaseUpdaterService;

  static const _currentDataVersion = '2025-03-01-laboratories-normalization';
  static const String dataVersion = _currentDataVersion;

  final AppDatabase _db;
  final String? _globalCacheDir;
  final BdpmFileValidator _validator;
  final BdpmDownloader _downloader;
  final BdpmParserService _parserService;
  final BdpmRepository _repository;
  final DatabaseUpdaterService? _databaseUpdaterService;
  final _stepController = StreamController<InitializationStep>.broadcast();
  final _detailController = StreamController<String>.broadcast();

  Stream<InitializationStep> get onStepChanged => _stepController.stream;
  Stream<String> get onDetailChanged => _detailController.stream;

  void dispose() {
    if (!_stepController.isClosed) {
      unawaited(_stepController.close());
    }
    if (!_detailController.isClosed) {
      unawaited(_detailController.close());
    }
  }

  Future<void> initializeDatabase({bool forceRefresh = false}) async {
    final (persistedVersion, hasExistingData) = await (
      _db.settingsDao.getBdpmVersion(),
      _db.catalogDao.hasExistingData(),
    ).wait;

    LoggerService.info(
      '[DataInit] initializeDatabase(forceRefresh: $forceRefresh, '
      'persisted: $persistedVersion, current: $_currentDataVersion, '
      'hasData: $hasExistingData)',
    );

    if (!forceRefresh &&
        persistedVersion == _currentDataVersion &&
        hasExistingData) {
      LoggerService.info(
        '[DataInit] Initialization skipped: cache matches current version.',
      );
      _stepController.add(InitializationStep.ready);
      return;
    }

    LoggerService.info(
      '[DataInit] Initialization required (force: $forceRefresh). '
      'Trying prebuilt database download first...',
    );

    // Essayer d'abord de télécharger la DB pré-générée
    final prebuiltDownloaded = await tryDownloadPrebuiltDatabase();
    if (prebuiltDownloaded) {
      LoggerService.info(
        '[DataInit] Prebuilt database downloaded successfully. Skipping BDPM parsing.',
      );
      // Vérifier que la DB est valide après téléchargement
      final hasData = await _db.catalogDao.hasExistingData();
      if (hasData) {
        try {
          await _db.settingsDao.updateBdpmVersion(_currentDataVersion);
        } on Exception catch (e, stackTrace) {
          LoggerService.error(
            '[DataInit] Failed to update BDPM version',
            e,
            stackTrace,
          );
        }
        await _markSyncAsFresh();
        _stepController.add(InitializationStep.ready);
        _safeEmitDetail(Strings.initializationReady);
        return;
      } else {
        LoggerService.warning(
          '[DataInit] Prebuilt database downloaded but appears empty. Falling back to BDPM parsing.',
        );
      }
    }

    // Fallback vers le parsing BDPM si le téléchargement a échoué ou si la DB est vide
    LoggerService.info(
      '[DataInit] Starting full BDPM refresh (download + parse + aggregate).',
    );
    await _performFullRefresh();
  }

  /// Tente de télécharger la base de données pré-générée depuis GitHub Releases
  ///
  /// Retourne `true` si le téléchargement et le remplacement ont réussi, `false` sinon.
  Future<bool> tryDownloadPrebuiltDatabase() async {
    if (_databaseUpdaterService == null) {
      LoggerService.info(
        '[DataInit] DatabaseUpdaterService not available, skipping prebuilt download',
      );
      return false;
    }

    try {
      _safeEmitDetail('Vérification des mises à jour...');
      _stepController.add(InitializationStep.downloading);

      final updated = await _databaseUpdaterService.checkForUpdate(_db);
      return updated;
    } catch (e, stackTrace) {
      LoggerService.error(
        '[DataInit] Failed to download prebuilt database, will fallback to BDPM parsing',
        e,
        stackTrace,
      );
      return false;
    }
  }

  Future<void> _performFullRefresh() async {
    try {
      LoggerService.info(
        '[DataInit] Starting full BDPM refresh (download + parse + aggregate).',
      );
      _safeEmitDetail(Strings.initializationStarting);
      _stepController.add(InitializationStep.downloading);

      var filePaths = <String, String>{};
      try {
        filePaths = await _downloader.downloadAllWithCacheCheck();
        await _validateFiles(filePaths);
      } on ValidationFailure catch (e, stackTrace) {
        LoggerService.error(
          '[DataInit] Validation failed for downloaded BDPM files',
          e,
          stackTrace,
        );
        await _deleteCachedFiles(filePaths.values);
        _stepController.add(InitializationStep.error);
        _safeEmitDetail(Strings.initializationError);
        rethrow;
      } on Exception catch (e, stackTrace) {
        LoggerService.warning(
          '[DataInit] Download failed, checking for existing database data: $e',
        );
        final hasExistingData = await _db.catalogDao.hasExistingData();
        if (hasExistingData) {
          LoggerService.info(
            '[DataInit] Using existing database data despite download failure. '
            'App will continue with cached data.',
          );
          _safeEmitDetail(Strings.initializationUsingExistingData);
          _stepController.add(InitializationStep.ready);
          return;
        }
        LoggerService.error(
          '[DataInit] Download failed and no existing database data available',
          e,
          stackTrace,
        );
        _stepController.add(InitializationStep.error);
        _safeEmitDetail(Strings.initializationError);
        rethrow;
      }

      _stepController.add(InitializationStep.parsing);
      _safeEmitDetail(Strings.dataOperationsParsingInProgress);
      await _parseAndInsertData(filePaths);

      _stepController.add(InitializationStep.aggregating);
      _safeEmitDetail(Strings.initializationAggregatingSummary);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _aggregateDataForSummary();

      try {
        await _db.settingsDao.updateBdpmVersion(_currentDataVersion);
      } on Exception catch (e, stackTrace) {
        LoggerService.error(
          '[DataInit] Failed to update BDPM version',
          e,
          stackTrace,
        );
      }
      await _markSyncAsFresh();

      _stepController.add(InitializationStep.ready);
      _safeEmitDetail(Strings.initializationReady);
    } on Exception catch (e, stackTrace) {
      LoggerService.error(
        '[DataInit] Error during full refresh',
        e,
        stackTrace,
      );
      _stepController.add(InitializationStep.error);
      _safeEmitDetail(Strings.initializationError);
      rethrow;
    }
  }

  Future<void> applyUpdate(Map<String, File> tempFiles) async {
    LoggerService.info('[DataInit] Applying updates from SyncService...');
    LoggerService.info(
      '[DataInit] Received ${tempFiles.length} files from SyncService.',
    );

    final cacheDir = _globalCacheDir;
    final appDir = await getApplicationDocumentsDirectory();

    for (final entry in tempFiles.entries) {
      final key = entry.key;
      final tempFile = entry.value;
      final sourceUrl = DataSources.files[key];
      if (sourceUrl == null) continue;

      final filename = _extractFilenameFromUrl(sourceUrl);
      final destinationPath = cacheDir != null
          ? p.join(cacheDir, filename)
          : p.join(appDir.path, filename);
      final destinationFile = File(destinationPath);

      if (!await destinationFile.parent.exists()) {
        await destinationFile.parent.create(recursive: true);
      }
      await tempFile.copy(destinationFile.path);
      LoggerService.info(
        '[DataInit] Copied updated file $key to cache: $destinationPath',
      );
    }

    Map<String, String> fullFilePaths;
    try {
      fullFilePaths = await _downloader.resolveFullFileSet(tempFiles);
      await _validateFiles(fullFilePaths);
    } on ValidationFailure catch (e, stackTrace) {
      LoggerService.error(
        '[DataInit] Validation failed for incremental update files',
        e,
        stackTrace,
      );
      await _deleteCachedFiles(tempFiles.values.map((file) => file.path));
      _stepController.add(InitializationStep.error);
      _safeEmitDetail(Strings.initializationError);
      rethrow;
    }

    await _parseAndInsertData(fullFilePaths);

    _stepController.add(InitializationStep.aggregating);
    _safeEmitDetail(Strings.initializationAggregatingSummary);
    await _aggregateDataForSummary();

    try {
      await _db.settingsDao.updateBdpmVersion(_currentDataVersion);
    } on Exception catch (e, stackTrace) {
      LoggerService.error(
        '[DataInit] Failed to update BDPM version',
        e,
        stackTrace,
      );
    }
    await _markSyncAsFresh();
  }

  Future<void> _validateFiles(Map<String, String> filePaths) async {
    for (final entry in filePaths.entries) {
      await _validator.validateHeader(File(entry.value), entry.key);
    }
  }

  Future<void> _parseAndInsertData(Map<String, String> filePaths) async {
    LoggerService.info(
      '[DataInit] Parsing BDPM files: ${filePaths.keys.join(', ')}.',
    );

    final parsedEither = await _parserService.parseAll(filePaths);

    final parsedBatch = parsedEither.fold(
      ifLeft: (failure) {
        LoggerService.error(
          '[DataInit] Failed to parse data',
          failure.message,
          failure.stackTrace,
        );
        _safeEmitDetail(Strings.initializationError);
        throw failure;
      },
      ifRight: (data) => data,
    );

    LoggerService.info(
      '[DataInit] Parsed ${parsedBatch.medicaments.length} medicaments, '
      '${parsedBatch.principes.length} principles, and '
      '${parsedBatch.groupMembers.length} group members.',
    );

    final insertEither = await _repository.insertDataWithRetry(parsedBatch);

    insertEither.fold(
      ifLeft: (failure) {
        LoggerService.error(
          '[DataInit] Failed to insert data',
          failure.message,
          failure.stackTrace,
        );
        _safeEmitDetail(Strings.initializationError);
        throw failure;
      },
      ifRight: (_) {
        LoggerService.info(
          '[DataInit] Successfully inserted parsed data into database.',
        );
      },
    );

    LoggerService.info(
      '[DataInit] Cross-validating group metadata against Type 0 members.',
    );
    await _db.databaseDao.refineGroupMetadata();
    LoggerService.info(
      '[DataInit] Completed group metadata refinement.',
    );
  }

  Future<void> _aggregateDataForSummary() async {
    LoggerService.info(
      '[DataInit] Starting data aggregation for MedicamentSummary table.',
    );

    _safeEmitDetail(Strings.initializationAggregatingSummaryTable);

    await _repository.aggregateSummary();
  }

  Future<void> _markSyncAsFresh() async {
    final now = DateTime.now();
    final sourcesWithDate = {
      for (final key in DataSources.files.keys) key: now,
    };

    try {
      await _db.settingsDao.saveSourceDates(sourcesWithDate);
    } on Exception catch (e, stackTrace) {
      LoggerService.error(
        '[DataInit] Failed to update source dates',
        e,
        stackTrace,
      );
    }

    try {
      await _db.settingsDao.updateSyncTimestamp(
        now.millisecondsSinceEpoch,
      );
    } on Exception catch (e, stackTrace) {
      LoggerService.error(
        '[DataInit] Failed to update sync timestamp',
        e,
        stackTrace,
      );
    }
  }

  void _safeEmitDetail(String message) {
    if (!_detailController.isClosed) {
      _detailController.add(message);
    }
  }

  @visibleForTesting
  Future<void> runSummaryAggregationForTesting() => _aggregateDataForSummary();

  static String? _resolveDefaultCacheDir() {
    final env = Platform.environment['PHARMA_BDPM_CACHE'];
    if (env != null && env.isNotEmpty) {
      final dir = Directory(env);
      if (dir.existsSync()) return dir.path;
    }
    final defaultDir = Directory(p.join('tool', 'data'));
    if (defaultDir.existsSync()) {
      return defaultDir.path;
    }
    return null;
  }

  String _extractFilenameFromUrl(String url) {
    final uri = Uri.parse(url);
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'bdpm.txt';
  }
}

Future<void> _deleteCachedFiles(Iterable<String> paths) async {
  for (final path in paths) {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } on Exception {
      // Best-effort cleanup.
    }
  }
}
