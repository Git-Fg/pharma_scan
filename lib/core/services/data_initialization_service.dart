import 'dart:async';
import 'dart:io';

import 'package:dart_either/dart_either.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/config/data_sources.dart';
import 'package:pharma_scan/core/database/daos/database_dao.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/errors/failures.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart'
    as parser;
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
    String? cacheDirectory,
    FileDownloadService? fileDownloadService,
  }) : _db = database,
       _globalCacheDir = cacheDirectory ?? _resolveDefaultCacheDir(),
       _fileDownloadService = fileDownloadService ?? FileDownloadService(),
       _validator = BdpmFileValidator();

  static const _currentDataVersion =
      '2025-03-01-laboratories-normalization'; // Normalizes titulaire into Laboratories table with integer FKs
  static const String dataVersion = _currentDataVersion;

  final AppDatabase _db;
  final String? _globalCacheDir;
  final FileDownloadService _fileDownloadService;
  final BdpmFileValidator _validator;
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
      'Starting full refresh…',
    );
    await _performFullRefresh();
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
        filePaths = await _downloadAllFilesWithCacheCheck();
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

  Future<Map<String, String>> _downloadAllFilesWithCacheCheck() async {
    final cachedFiles = <String, String>{};
    final missingFiles = <MapEntry<String, String>>[];

    for (final entry in DataSources.files.entries) {
      final filename = _extractFilenameFromUrl(entry.value);
      final cacheDir = _globalCacheDir;

      if (cacheDir != null) {
        final cacheFile = File(p.join(cacheDir, filename));
        if (await cacheFile.exists()) {
          LoggerService.info(
            '[DataInit] Using cached BDPM file $filename from $cacheDir',
          );
          _safeEmitDetail(
            Strings.initializationUsingCachedFile(filename),
          );
          cachedFiles[entry.key] = cacheFile.path;
          continue;
        }
      }

      missingFiles.add(entry);
    }

    if (missingFiles.isEmpty) {
      LoggerService.info(
        '[DataInit] All BDPM files found in cache - skipping downloads',
      );
      return cachedFiles;
    }

    var completedCount = 0;
    final totalToDownload = missingFiles.length;
    final downloadFutures = missingFiles.map(
      (entry) async {
        try {
          LoggerService.info(
            '[DataInit] Downloading ${entry.key} from ${entry.value}',
          );
          _safeEmitDetail(
            Strings.initializationDownloadingFile(
              _extractFilenameFromUrl(entry.value),
            ),
          );
          final path = await _getFilePath(entry.key, entry.value);
          completedCount += 1;
          _safeEmitDetail(
            Strings.initializationDownloadProgress(
              completedCount,
              totalToDownload,
            ),
          );
          LoggerService.info('[DataInit] Downloaded ${entry.key} to $path');
          return MapEntry(entry.key, path);
        } on Exception catch (e, stackTrace) {
          final filename = _extractFilenameFromUrl(entry.value);
          final cacheDir = _globalCacheDir;
          File? fallbackFile;

          if (cacheDir != null) {
            final cacheFile = File(p.join(cacheDir, filename));
            if (await cacheFile.exists()) {
              fallbackFile = cacheFile;
            }
          }

          if (fallbackFile == null) {
            final directory = await getApplicationDocumentsDirectory();
            final appCacheFile = File('${directory.path}/$filename');
            if (await appCacheFile.exists()) {
              fallbackFile = appCacheFile;
            }
          }

          if (fallbackFile != null) {
            LoggerService.warning(
              '[DataInit] Download failed for ${entry.key}, using cached file: $e',
            );
            _safeEmitDetail(
              Strings.initializationUsingCachedFile(
                _extractFilenameFromUrl(entry.value),
              ),
            );
            return MapEntry(entry.key, fallbackFile.path);
          }

          LoggerService.error(
            '[DataInit] Download failed for ${entry.key} and no cache available',
            e,
            stackTrace,
          );
          throw Exception(
            'Failed to download ${entry.key} (${_extractFilenameFromUrl(entry.value)}): $e',
          );
        }
      },
    );

    final downloadResults = await Future.wait(downloadFutures);

    return {...cachedFiles, ...Map.fromEntries(downloadResults)};
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
      fullFilePaths = await _resolveFullFileSet(tempFiles);
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

  /// Resolves the complete set of BDPM file paths required for parsing.
  ///
  /// For each file in [DataSources.files]:
  /// - If present in [updatedFiles], uses the cached path (after temp file was copied)
  /// - If absent, resolves from cache (global cache dir or app documents directory)
  ///
  /// Throws [Exception] if any required file is missing from both update and cache.
  Future<Map<String, String>> _resolveFullFileSet(
    Map<String, File> updatedFiles,
  ) async {
    final filePaths = <String, String>{};
    final cacheDir = _globalCacheDir;
    final appDir = await getApplicationDocumentsDirectory();
    final missingFiles = <String>[];

    for (final key in DataSources.files.keys) {
      final sourceUrl = DataSources.files[key];
      if (sourceUrl == null) continue;

      final filename = _extractFilenameFromUrl(sourceUrl);

      if (updatedFiles.containsKey(key)) {
        final destinationPath = cacheDir != null
            ? p.join(cacheDir, filename)
            : p.join(appDir.path, filename);
        final destinationFile = File(destinationPath);

        if (await destinationFile.exists()) {
          filePaths[key] = destinationPath;
          LoggerService.info(
            '[DataInit] Using updated file $key from cache: $destinationPath',
          );
          continue;
        } else {
          LoggerService.warning(
            '[DataInit] Updated file $key not found at expected cache path: $destinationPath',
          );
        }
      }

      File? cachedFile;

      if (cacheDir != null) {
        final cacheFile = File(p.join(cacheDir, filename));
        if (await cacheFile.exists()) {
          cachedFile = cacheFile;
        }
      }

      if (cachedFile == null) {
        final appCacheFile = File(p.join(appDir.path, filename));
        if (await appCacheFile.exists()) {
          cachedFile = appCacheFile;
        }
      }

      if (cachedFile != null) {
        filePaths[key] = cachedFile.path;
        LoggerService.info(
          '[DataInit] Using cached file $key: ${cachedFile.path}',
        );
      } else {
        missingFiles.add(key);
      }
    }

    if (missingFiles.isNotEmpty) {
      throw Exception(
        'Required BDPM files missing from both update and cache: '
        '${missingFiles.join(', ')}. Full initialization required.',
      );
    }

    LoggerService.info(
      '[DataInit] Resolved complete file set (${filePaths.length} files): '
      '${filePaths.keys.join(', ')}',
    );

    return filePaths;
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

    final args = (filePaths: filePaths);
    final resultEither = await compute(_parseDataInBackground, args);

    final parsedBatch = resultEither.fold(
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
      '${parsedBatch.groupMembers.length} group members in isolate.',
    );

    final insertEither = await _insertDataWithRetry(
      database: _db,
      ingestionBatch: parsedBatch,
    );

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

  Future<String> _getFilePath(String storageKey, String url) async {
    final filename = _extractFilenameFromUrl(url);
    final cacheDir = _globalCacheDir;

    if (cacheDir != null) {
      final cacheFile = File(p.join(cacheDir, filename));
      if (await cacheFile.exists()) {
        LoggerService.info(
          '[DataInit] Using cached BDPM file $filename from $cacheDir',
        );
        return cacheFile.path;
      }
    }

    final bytes = await _fetchFileBytesWithCache(url: url, filename: filename);

    if (cacheDir != null) {
      await _writeGlobalCache(filename, bytes);
      return File(p.join(cacheDir, filename)).path;
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  String _extractFilenameFromUrl(String url) {
    final uri = Uri.parse(url);
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'bdpm.txt';
  }

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

  Future<void> _writeGlobalCache(String filename, List<int> bytes) async {
    final cacheDir = _globalCacheDir;
    if (cacheDir == null) return;
    final file = File(p.join(cacheDir, filename));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<List<int>> _fetchFileBytesWithCache({
    required String url,
    required String filename,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheFile = File('${directory.path}/$filename');

    const maxRetries = 3;
    var retryCount = 0;
    while (retryCount < maxRetries) {
      final downloadEither = await _fileDownloadService
          .downloadToBytesWithCacheFallback(
            url: url,
            cacheFile: cacheFile,
          );

      final result = downloadEither.fold(
        ifLeft: (failure) {
          retryCount++;
          if (retryCount >= maxRetries) {
            return null;
          }
          final delayMs = 2000 * (1 << (retryCount - 1));
          LoggerService.warning(
            '[DataInit] Download failed for $filename (attempt $retryCount/$maxRetries), retrying in ${delayMs}ms: ${failure.message}',
          );
          return null; // Signal retry needed
        },
        ifRight: (bytes) => bytes,
      );

      if (result != null) {
        return result;
      }

      if (retryCount < maxRetries) {
        final delayMs = 2000 * (1 << (retryCount - 1));
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }

    if (await cacheFile.exists()) {
      LoggerService.warning(
        '[DataInit] Download failed after $maxRetries attempts, using cached file: $filename',
      );
      return cacheFile.readAsBytes();
    }

    throw Exception(
      'Failed to download $filename after $maxRetries attempts and no cache available',
    );
  }

  @visibleForTesting
  Future<void> runSummaryAggregationForTesting() => _aggregateDataForSummary();

  Future<void> _aggregateDataForSummary() async {
    LoggerService.info(
      '[DataInit] Starting data aggregation for MedicamentSummary table.',
    );

    _safeEmitDetail(Strings.initializationAggregatingSummaryTable);

    final recordCount = await _db.databaseDao.populateSummaryTable();
    _safeEmitDetail(Strings.initializationAggregatingFtsIndex);
    await _db.databaseDao.populateFts5Index();

    LoggerService.db(
      'Aggregated $recordCount records into MedicamentSummary table using SQL aggregation.',
    );
  }

  void _safeEmitDetail(String message) {
    if (!_detailController.isClosed) {
      _detailController.add(message);
    }
  }
}

Future<void> _insertChunked<T>(
  AppDatabase db,
  void Function(Batch batch, List<T> chunk, InsertMode mode) inserter,
  Iterable<T> items, {
  InsertMode mode = InsertMode.insert,
}) async {
  final itemsList = items.toList();
  if (itemsList.isEmpty) return;

  for (var i = 0; i < itemsList.length; i += AppConfig.batchSize) {
    final end = (i + AppConfig.batchSize < itemsList.length)
        ? i + AppConfig.batchSize
        : itemsList.length;
    final chunk = itemsList.sublist(i, end);

    await db.batch((batch) {
      inserter(batch, chunk, mode);
    });
  }
}

/// Maps [parser.ParseError] to [ParsingFailure] for domain error handling.
Failure _mapParseErrorToFailure(parser.ParseError error) {
  return switch (error) {
    parser.EmptyContentError(:final fileName) => ParsingFailure(
      'Failed to parse $fileName: file is empty or missing',
    ),
    parser.InvalidFormatError(:final fileName, :final details) =>
      ParsingFailure(
        'Failed to parse $fileName: $details',
      ),
  };
}

/// Inserts parsed data into the database with retry logic for lock errors.
/// Returns [Either.left] if all retries fail, [Either.right] on success.
Future<Either<Failure, void>> _insertDataWithRetry({
  required AppDatabase database,
  required IngestionBatch ingestionBatch,
}) async {
  const maxRetries = 6;
  const busyTimeoutMs = 30000;
  const baseDelayMs = 800;
  const maxDelayMs = 6400;
  var retryCount = 0;
  var totalDelayMs = 0;
  Failure? lastFailure;

  while (retryCount < maxRetries) {
    final insertResult = await Either.catchFutureError<Failure, void>(
      (error, stackTrace) => DatabaseFailure(
        'Database insertion failed: $error',
        stackTrace,
      ),
      () async {
        await database.transaction(() async {
          if (ingestionBatch.laboratories.isNotEmpty) {
            await _insertChunked(
              database,
              (batch, chunk, mode) =>
                  batch.insertAll(database.laboratories, chunk, mode: mode),
              ingestionBatch.laboratories,
              mode: InsertMode.replace,
            );
          }

          await _insertChunked(
            database,
            (batch, chunk, mode) =>
                batch.insertAll(database.specialites, chunk, mode: mode),
            ingestionBatch.specialites,
            mode: InsertMode.replace,
          );

          await _insertChunked(
            database,
            (batch, chunk, mode) =>
                batch.insertAll(database.medicaments, chunk, mode: mode),
            ingestionBatch.medicaments,
            mode: InsertMode.replace,
          );

          await _insertChunked(
            database,
            (batch, chunk, mode) =>
                batch.insertAll(database.principesActifs, chunk, mode: mode),
            ingestionBatch.principes,
          );

          await _insertChunked(
            database,
            (batch, chunk, mode) =>
                batch.insertAll(database.generiqueGroups, chunk, mode: mode),
            ingestionBatch.generiqueGroups,
            mode: InsertMode.replace,
          );

          await _insertChunked(
            database,
            (batch, chunk, mode) =>
                batch.insertAll(database.groupMembers, chunk, mode: mode),
            ingestionBatch.groupMembers,
            mode: InsertMode.replace,
          );

          await database.batch((batch) {
            batch.deleteWhere(
              database.medicamentAvailability,
              (_) => const Constant(true),
            );
          });

          if (ingestionBatch.availability.isNotEmpty) {
            await _insertChunked(
              database,
              (batch, chunk, mode) => batch.insertAll(
                database.medicamentAvailability,
                chunk,
                mode: mode,
              ),
              ingestionBatch.availability,
              mode: InsertMode.replace,
            );
          }
        });
      },
    );

    if (insertResult.isRight) {
      return insertResult;
    }

    lastFailure = insertResult.fold(
      ifLeft: (failure) => failure,
      ifRight: (_) => throw StateError('Unreachable'),
    );

    retryCount++;
    if (retryCount >= maxRetries) {
      return Either<Failure, void>.left(lastFailure!);
    }

    final expDelay = baseDelayMs * (1 << (retryCount - 1));
    final delayMs = expDelay > maxDelayMs ? maxDelayMs : expDelay;
    totalDelayMs += delayMs;
    final remainingBudget = busyTimeoutMs - totalDelayMs;
    LoggerService.warning(
      '[DataInit] Database lock error (attempt $retryCount/$maxRetries, '
      'busy_timeout=${busyTimeoutMs}ms, waited=${totalDelayMs}ms, '
      'nextDelay=${delayMs}ms, remainingBudget=${remainingBudget}ms): '
      '${lastFailure!.message}',
    );
    await Future<void>.delayed(Duration(milliseconds: delayMs));
  }

  return Either<Failure, void>.left(
    lastFailure ??
        const DatabaseFailure('Database insertion failed after retries'),
  );
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

Future<Either<Failure, IngestionBatch>> _parseDataInBackground(
  ParseDataArgs args,
) async {
  Stream<String>? streamForKey(String key) =>
      parser.BdpmFileParser.openLineStream(args.filePaths[key]);
  return Either.futureBinding<Failure, IngestionBatch>((
    e,
  ) async {
    final independentResults = await Future.wait<Map<String, String>>([
      parser.BdpmFileParser.parseConditions(streamForKey('conditions')),
      parser.BdpmFileParser.parseMitm(streamForKey('mitm')),
    ]);
    final conditionsMap = independentResults[0];
    final mitmMap = independentResults[1];

    final specialitesEither = await parser.BdpmFileParser.parseSpecialites(
      streamForKey('specialites'),
      conditionsMap,
      mitmMap,
    );
    final specialitesResult = specialitesEither
        .mapLeft<Failure>(_mapParseErrorToFailure)
        .bind(e);

    final medicamentsEither = await parser.BdpmFileParser.parseMedicaments(
      streamForKey('medicaments'),
      specialitesResult,
    );
    final medicamentsResult = medicamentsEither
        .mapLeft<Failure>(_mapParseErrorToFailure)
        .bind(e);

    final compositionMap = await parser.BdpmFileParser.parseCompositions(
      streamForKey('compositions'),
    );

    final principesEither = await parser.BdpmFileParser.parsePrincipesActifs(
      streamForKey('compositions'),
      medicamentsResult.cisToCip13,
    );
    final principes = principesEither
        .mapLeft<Failure>(_mapParseErrorToFailure)
        .bind(e);

    final generiqueEither = await parser.BdpmFileParser.parseGeneriques(
      streamForKey('generiques'),
      medicamentsResult.cisToCip13,
      medicamentsResult.medicamentCips,
      compositionMap,
      specialitesResult.namesByCis,
    );
    final generiqueResult = generiqueEither
        .mapLeft<Failure>(_mapParseErrorToFailure)
        .bind(e);

    final availabilityEither = await parser.BdpmFileParser.parseAvailability(
      streamForKey('availability'),
      medicamentsResult.cisToCip13,
    );
    final availability = availabilityEither
        .mapLeft<Failure>(_mapParseErrorToFailure)
        .bind(e);

    final laboratories = specialitesResult.laboratories;

    return IngestionBatch(
      specialites: specialitesResult.specialites,
      medicaments: medicamentsResult.medicaments,
      principes: principes,
      generiqueGroups: generiqueResult.generiqueGroups,
      groupMembers: generiqueResult.groupMembers,
      laboratories: laboratories,
      availability: availability,
    );
  });
}
