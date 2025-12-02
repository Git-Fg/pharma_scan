import 'dart:async';
import 'dart:io';

import 'package:dart_either/dart_either.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/config/data_sources.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/errors/failures.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';
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
       _fileDownloadService = fileDownloadService ?? FileDownloadService();

  static const _currentDataVersion =
      '2025-01-30-sync-fix'; // Fixed incremental sync data corruption by ensuring all 7 BDPM files are available to parser
  static const String dataVersion = _currentDataVersion;

  final AppDatabase _db;
  final String? _globalCacheDir;
  final FileDownloadService _fileDownloadService;
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
    final persistedVersion = await _db.settingsDao.getBdpmVersion();

    final hasExistingData = await _db.catalogDao.hasExistingData();

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

      Map<String, String> filePaths;
      try {
        filePaths = await _downloadAllFilesWithCacheCheck();
      } catch (e, stackTrace) {
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
          final updateEither = await _db.settingsDao.updateBdpmVersion(
            _currentDataVersion,
          );
          updateEither.fold(
            ifLeft: (failure) {
              LoggerService.error(
                '[DataInit] Failed to update BDPM version',
                failure.message,
                failure.stackTrace,
              );
            },
            ifRight: (_) {},
          );
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

      final updateEither = await _db.settingsDao.updateBdpmVersion(
        _currentDataVersion,
      );
      updateEither.fold(
        ifLeft: (failure) {
          LoggerService.error(
            '[DataInit] Failed to update BDPM version',
            failure.message,
            failure.stackTrace,
          );
        },
        ifRight: (_) {},
      );
      await _markSyncAsFresh();

      _stepController.add(InitializationStep.ready);
      _safeEmitDetail(Strings.initializationReady);
    } catch (e, stackTrace) {
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

    final downloadResults = <MapEntry<String, String>>[];
    final downloadErrors = <String, Object>{}; // Track which files failed

    for (final entry in missingFiles) {
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
        LoggerService.info('[DataInit] Downloaded ${entry.key} to $path');
        downloadResults.add(MapEntry(entry.key, path));
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
          downloadResults.add(MapEntry(entry.key, fallbackFile.path));
        } else {
          LoggerService.error(
            '[DataInit] Download failed for ${entry.key} and no cache available',
            e,
            stackTrace,
          );
          downloadErrors[entry.key] = e;
        }
      }
    }

    if (downloadErrors.isNotEmpty &&
        downloadResults.isEmpty &&
        cachedFiles.isEmpty) {
      throw Exception(
        'Failed to download required files and no cache available: ${downloadErrors.keys.join(', ')}',
      );
    }

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

    final fullFilePaths = await _resolveFullFileSet(tempFiles);
    await _parseAndInsertData(fullFilePaths);

    final updateEither = await _db.settingsDao.updateBdpmVersion(
      _currentDataVersion,
    );
    updateEither.fold(
      ifLeft: (failure) {
        LoggerService.error(
          '[DataInit] Failed to update BDPM version',
          failure.message,
          failure.stackTrace,
        );
      },
      ifRight: (_) {},
    );
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
      '[DataInit] Parsed ${parsedBatch.medicamentsResult.medicaments.length} medicaments, '
      '${parsedBatch.principes.length} principles, and '
      '${parsedBatch.generiqueResult.groupMembers.length} group members in isolate.',
    );

    final insertEither = await _insertDataWithRetry(
      database: _db,
      parsedBatch: parsedBatch,
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

    LoggerService.info(
      '[DataInit] Persisted parsed data. Aggregating summary table next.',
    );
    await _aggregateDataForSummary();
  }

  Future<void> _markSyncAsFresh() async {
    final updateEither = await _db.settingsDao.updateSyncTimestamp(
      DateTime.now().millisecondsSinceEpoch,
    );
    updateEither.fold(
      ifLeft: (failure) {
        LoggerService.error(
          '[DataInit] Failed to update sync timestamp',
          failure.message,
          failure.stackTrace,
        );
      },
      ifRight: (_) {},
    );
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

/// Maps [ParseError] to [ParsingFailure] for domain error handling.
Failure _mapParseErrorToFailure(ParseError error) {
  return switch (error) {
    EmptyContentError(:final fileName) => ParsingFailure(
      'Failed to parse $fileName: file is empty or missing',
    ),
    InvalidFormatError(:final fileName, :final details) => ParsingFailure(
      'Failed to parse $fileName: $details',
    ),
  };
}

/// Inserts parsed data into the database with retry logic for lock errors.
/// Returns [Either.left] if all retries fail, [Either.right] on success.
Future<Either<Failure, void>> _insertDataWithRetry({
  required AppDatabase database,
  required _ParsedDataBatch parsedBatch,
}) async {
  const maxRetries = 5;
  var retryCount = 0;
  Failure? lastFailure;

  while (retryCount < maxRetries) {
    final insertResult = await Either.catchFutureError<Failure, void>(
      (error, stackTrace) => DatabaseFailure(
        'Database insertion failed: $error',
        stackTrace,
      ),
      () async {
        final specialitesCompanions = parsedBatch.specialitesResult.specialites
            .map(
              (row) => SpecialitesCompanion(
                cisCode: Value(row.cisCode),
                nomSpecialite: Value(row.nomSpecialite),
                procedureType: Value(row.procedureType),
                statutAdministratif: Value(row.statutAdministratif),
                formePharmaceutique: Value(row.formePharmaceutique),
                voiesAdministration: Value(row.voiesAdministration),
                etatCommercialisation: Value(row.etatCommercialisation),
                titulaire: Value(row.titulaire),
                conditionsPrescription: Value(row.conditionsPrescription),
                atcCode: Value(row.atcCode),
                isSurveillance: Value(row.isSurveillance),
              ),
            );
        await _insertChunked(
          database,
          (batch, chunk, mode) =>
              batch.insertAll(database.specialites, chunk, mode: mode),
          specialitesCompanions,
          mode: InsertMode.replace,
        );

        final medicamentsCompanions = parsedBatch.medicamentsResult.medicaments
            .map(
              (row) => MedicamentsCompanion(
                codeCip: Value(row.codeCip),
                cisCode: Value(row.cisCode),
                presentationLabel: Value(row.presentationLabel),
                commercialisationStatut: Value(row.commercialisationStatut),
                tauxRemboursement: Value(row.tauxRemboursement),
                prixPublic: Value(row.prixPublic),
                agrementCollectivites: Value(row.agrementCollectivites),
              ),
            );
        await _insertChunked(
          database,
          (batch, chunk, mode) =>
              batch.insertAll(database.medicaments, chunk, mode: mode),
          medicamentsCompanions,
          mode: InsertMode.replace,
        );

        final principesCompanions = parsedBatch.principes.map(
          (row) => PrincipesActifsCompanion(
            codeCip: Value(row.codeCip),
            principe: Value(row.principe),
            principeNormalized: Value(
              row.principe.isNotEmpty
                  ? normalizePrincipleOptimal(row.principe)
                  : null,
            ),
            dosage: Value(row.dosage),
            dosageUnit: Value(row.dosageUnit),
          ),
        );
        await _insertChunked(
          database,
          (batch, chunk, mode) =>
              batch.insertAll(database.principesActifs, chunk, mode: mode),
          principesCompanions,
        );

        final generiqueGroupsCompanions = parsedBatch
            .generiqueResult
            .generiqueGroups
            .map(
              (row) => GeneriqueGroupsCompanion(
                groupId: Value(row.groupId),
                libelle: Value(row.libelle),
                princepsLabel: Value(row.princepsLabel),
                moleculeLabel: Value(row.moleculeLabel),
              ),
            );
        await _insertChunked(
          database,
          (batch, chunk, mode) =>
              batch.insertAll(database.generiqueGroups, chunk, mode: mode),
          generiqueGroupsCompanions,
          mode: InsertMode.replace,
        );

        final groupMembersCompanions = parsedBatch.generiqueResult.groupMembers
            .map(
              (row) => GroupMembersCompanion(
                codeCip: Value(row.codeCip),
                groupId: Value(row.groupId),
                type: Value(row.type),
              ),
            );
        await _insertChunked(
          database,
          (batch, chunk, mode) =>
              batch.insertAll(database.groupMembers, chunk, mode: mode),
          groupMembersCompanions,
          mode: InsertMode.replace,
        );

        await database.batch((batch) {
          batch.deleteWhere(
            database.medicamentAvailability,
            (_) => const Constant(true),
          );
        });

        if (parsedBatch.availabilityRows.isNotEmpty) {
          final availabilityCompanions = parsedBatch.availabilityRows.map(
            (row) => MedicamentAvailabilityCompanion(
              codeCip: Value(row.codeCip),
              statut: Value(row.statut),
              dateDebut: Value(row.dateDebut),
              dateFin: Value(row.dateFin),
              lien: Value(row.lien),
            ),
          );
          await _insertChunked(
            database,
            (batch, chunk, mode) => batch.insertAll(
              database.medicamentAvailability,
              chunk,
              mode: mode,
            ),
            availabilityCompanions,
            mode: InsertMode.replace,
          );
        }
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

    final delayMs = 500 * (1 << (retryCount - 1));
    LoggerService.warning(
      '[DataInit] Database lock error (attempt $retryCount/$maxRetries), retrying in ${delayMs}ms: ${lastFailure!.message}',
    );
    await Future<void>.delayed(Duration(milliseconds: delayMs));
  }

  return Either<Failure, void>.left(
    lastFailure ??
        const DatabaseFailure('Database insertion failed after retries'),
  );
}

Future<Either<Failure, _ParsedDataBatch>> _parseDataInBackground(
  ParseDataArgs args,
) async {
  Stream<String>? streamForKey(String key) =>
      BdpmFileParser.openLineStream(args.filePaths[key]);
  return Either.futureBinding<Failure, _ParsedDataBatch>((
    e,
  ) async {
    final conditionsMap = await BdpmFileParser.parseConditions(
      streamForKey('conditions'),
    );
    final mitmMap = await BdpmFileParser.parseMitm(streamForKey('mitm'));

    final specialitesEither = await BdpmFileParser.parseSpecialites(
      streamForKey('specialites'),
      conditionsMap,
      mitmMap,
    );
    final specialitesResult = specialitesEither
        .mapLeft(_mapParseErrorToFailure)
        .bind(e);

    final medicamentsEither = await BdpmFileParser.parseMedicaments(
      streamForKey('medicaments'),
      specialitesResult,
    );
    final medicamentsResult = medicamentsEither
        .mapLeft(_mapParseErrorToFailure)
        .bind(e);

    final principesEither = await BdpmFileParser.parseCompositions(
      streamForKey('compositions'),
      medicamentsResult.cisToCip13,
    );
    final principes = principesEither.mapLeft(_mapParseErrorToFailure).bind(e);

    final generiqueEither = await BdpmFileParser.parseGeneriques(
      streamForKey('generiques'),
      medicamentsResult.cisToCip13,
      medicamentsResult.medicamentCips,
    );
    final generiqueResult = generiqueEither
        .mapLeft(_mapParseErrorToFailure)
        .bind(e);

    final availabilityEither = await BdpmFileParser.parseAvailability(
      streamForKey('availability'),
      medicamentsResult.cisToCip13,
    );
    final availabilityRows = availabilityEither
        .mapLeft(_mapParseErrorToFailure)
        .bind(e);

    return _ParsedDataBatch(
      specialitesResult: specialitesResult,
      medicamentsResult: medicamentsResult,
      principes: principes,
      generiqueResult: generiqueResult,
      availabilityRows: availabilityRows,
    );
  });
}

class _ParsedDataBatch {
  const _ParsedDataBatch({
    required this.specialitesResult,
    required this.medicamentsResult,
    required this.principes,
    required this.generiqueResult,
    required this.availabilityRows,
  });

  final SpecialitesParseResult specialitesResult;
  final MedicamentsParseResult medicamentsResult;
  final List<PrincipeRow> principes;
  final GeneriquesParseResult generiqueResult;
  final List<AvailabilityRow> availabilityRows;
}
