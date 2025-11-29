// lib/core/services/data_initialization_service.dart
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/config/data_sources.dart';
import 'package:pharma_scan/core/database/database.dart' as drift_db;
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

typedef ParseAndInsertArgs = ({
  String dbPath,
  String tempPath,
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
      '2025-01-29-representative-cip'; // Updated to include representative_cip in MedicamentSummary for SQL-first search
  static const String dataVersion = _currentDataVersion;

  final AppDatabase _db;
  final String? _globalCacheDir;
  final FileDownloadService _fileDownloadService;
  final _stepController = StreamController<InitializationStep>.broadcast();

  Stream<InitializationStep> get onStepChanged => _stepController.stream;

  Future<void> initializeDatabase({bool forceRefresh = false}) async {
    final persistedVersion = await _db.settingsDao.getBdpmVersion();
    final hasExistingData = await _db.libraryDao.hasExistingData();

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
      // WHY: Check for cached files first - if they exist, use them immediately
      // This makes initialization much faster on subsequent launches
      _stepController.add(InitializationStep.downloading);

      Map<String, String> filePaths;
      try {
        filePaths = await _downloadAllFilesWithCacheCheck();
      } catch (e, stackTrace) {
        // WHY: If download fails, check if we have existing database data
        // If database has data, continue with that instead of failing
        LoggerService.warning(
          '[DataInit] Download failed, checking for existing database data: $e',
        );
        final hasExistingData = await _db.libraryDao.hasExistingData();
        if (hasExistingData) {
          LoggerService.info(
            '[DataInit] Using existing database data despite download failure. '
            'App will continue with cached data.',
          );
          // WHY: Mark as ready with existing data - user can retry download later
          await _db.settingsDao.updateBdpmVersion(_currentDataVersion);
          _stepController.add(InitializationStep.ready);
          return;
        }
        // WHY: No existing data and download failed - rethrow to show error
        LoggerService.error(
          '[DataInit] Download failed and no existing database data available',
          e,
          stackTrace,
        );
        _stepController.add(InitializationStep.error);
        rethrow;
      }

      _stepController.add(InitializationStep.parsing);
      await _parseAndInsertData(filePaths);

      _stepController.add(InitializationStep.aggregating);
      // WHY: Add delay before aggregation to ensure isolate database operations complete
      // This helps prevent "database is locked" errors when main thread tries to aggregate
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _aggregateDataForSummary();

      await _db.settingsDao.updateBdpmVersion(_currentDataVersion);
      await _markSyncAsFresh();

      _stepController.add(InitializationStep.ready);
    } catch (e, stackTrace) {
      LoggerService.error(
        '[DataInit] Error during full refresh',
        e,
        stackTrace,
      );
      _stepController.add(InitializationStep.error);
      rethrow;
    }
  }

  Future<Map<String, String>> _downloadAllFilesWithCacheCheck() async {
    // WHY: Check for cached files first - if all files are cached, use them immediately
    // This avoids network delays and makes initialization much faster
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
          cachedFiles[entry.key] = cacheFile.path;
          continue;
        }
      }

      missingFiles.add(entry);
    }

    // WHY: If all files are cached, return immediately - no network delay
    if (missingFiles.isEmpty) {
      LoggerService.info(
        '[DataInit] All BDPM files found in cache - skipping downloads',
      );
      return cachedFiles;
    }

    // WHY: Download only missing files, handling individual failures gracefully
    // If a download fails but we have cached files, we can still proceed
    final downloadResults = <MapEntry<String, String>>[];
    final downloadErrors = <String, Object>{}; // Track which files failed

    for (final entry in missingFiles) {
      try {
        LoggerService.info(
          '[DataInit] Downloading ${entry.key} from ${entry.value}',
        );
        final path = await _getFilePath(entry.key, entry.value);
        LoggerService.info('[DataInit] Downloaded ${entry.key} to $path');
        downloadResults.add(MapEntry(entry.key, path));
      } catch (e, stackTrace) {
        // WHY: If download fails, check if we have a cached version
        final filename = _extractFilenameFromUrl(entry.value);
        final cacheDir = _globalCacheDir;
        File? fallbackFile;

        if (cacheDir != null) {
          final cacheFile = File(p.join(cacheDir, filename));
          if (await cacheFile.exists()) {
            fallbackFile = cacheFile;
          }
        }

        // WHY: Check application documents directory as fallback
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
          downloadResults.add(MapEntry(entry.key, fallbackFile.path));
        } else {
          // WHY: Track error but don't fail immediately - let caller decide
          LoggerService.error(
            '[DataInit] Download failed for ${entry.key} and no cache available',
            e,
            stackTrace,
          );
          downloadErrors[entry.key] = e;
        }
      }
    }

    // WHY: If we have errors and no results, throw to be handled by caller
    if (downloadErrors.isNotEmpty &&
        downloadResults.isEmpty &&
        cachedFiles.isEmpty) {
      throw Exception(
        'Failed to download required files and no cache available: ${downloadErrors.keys.join(', ')}',
      );
    }

    // WHY: Combine cached and downloaded files
    return {...cachedFiles, ...Map.fromEntries(downloadResults)};
  }

  Future<void> applyUpdate(Map<String, File> tempFiles) async {
    LoggerService.info('[DataInit] Applying updates from SyncService...');
    LoggerService.info(
      '[DataInit] Received ${tempFiles.length} files from SyncService.',
    );

    final filePaths = <String, String>{};
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
      filePaths[key] = destinationFile.path;
    }

    await _parseAndInsertData(filePaths);

    await _db.settingsDao.updateBdpmVersion(_currentDataVersion);
    await _markSyncAsFresh();
  }

  Future<void> _parseAndInsertData(Map<String, String> filePaths) async {
    LoggerService.info(
      '[DataInit] Parsing BDPM files: ${filePaths.keys.join(', ')}.',
    );

    // WHY: Pass only database path and temp path to isolate (~1KB) instead of large data structures
    // Parsing and batch insertion happen entirely inside the isolate
    // WHY: Skip clearing to avoid database lock conflicts - INSERT OR REPLACE will overwrite existing data
    // This eliminates the need for separate DELETE operations that cause lock conflicts
    //
    // CRITICAL: SQLite isolate locking on Android
    // On Android, SQLite uses file-level locking. When the main isolate has an open database connection,
    // the background isolate cannot open the same database file, resulting in "database is locked" errors.
    // These delays ensure all database operations in the main isolate complete and connections are fully
    // released before the background isolate attempts to open the database.
    //
    // DO NOT REMOVE OR REDUCE THESE DELAYS - they are essential for preventing database lock conflicts
    // on Android devices. The total delay (600ms) is minimal compared to the parsing time (seconds).
    // WHY: Multiple delays force multiple event loop ticks, ensuring pending database operations complete
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final dbPath = await _getDatabasePath();
    final tempPath = (await getTemporaryDirectory()).path;
    final args = (dbPath: dbPath, tempPath: tempPath, filePaths: filePaths);

    final result = await compute(_parseAndInsertDataInBackground, args);

    LoggerService.info(
      '[DataInit] Parsed and inserted ${result.medicamentCount} medicaments, '
      '${result.principeCount} principles, and '
      '${result.groupMemberCount} group members in isolate.',
    );

    LoggerService.info(
      '[DataInit] Persisted parsed data. Aggregating summary table next.',
    );
    // Phase 2: Aggregate data for MedicamentSummary table
    await _aggregateDataForSummary();
  }

  Future<void> _markSyncAsFresh() async {
    // WHY: SyncService reads this timestamp to skip redundant checks right
    // after a successful initialization run.
    await _db.settingsDao.updateSyncTimestamp(
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<String> _getFilePath(String storageKey, String url) async {
    final filename = _extractFilenameFromUrl(url);
    final cacheDir = _globalCacheDir;

    // Ensure cache directory exists
    if (cacheDir != null) {
      final cacheFile = File(p.join(cacheDir, filename));
      if (await cacheFile.exists()) {
        LoggerService.info(
          '[DataInit] Using cached BDPM file $filename from $cacheDir',
        );
        return cacheFile.path;
      }
    }

    // Download and cache the file if not already cached
    final bytes = await _fetchFileBytesWithCache(url: url, filename: filename);

    // Write to global cache
    if (cacheDir != null) {
      await _writeGlobalCache(filename, bytes);
      return File(p.join(cacheDir, filename)).path;
    }

    // Fallback to application documents directory
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
    // Use tool/data/ as default cache directory (shared with standalone scripts)
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

    // WHY: Retry logic with exponential backoff to handle transient network errors
    // (connection timeouts, connection closed, etc.)
    const maxRetries = 3;
    var retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        // WHY: Use centralized FileDownloader service for consistent error handling,
        // timeouts, and Talker logging across all file downloads.
        return await _fileDownloadService.downloadToBytesWithCacheFallback(
          url: url,
          cacheFile: cacheFile,
        );
      } catch (error) {
        retryCount++;
        if (retryCount >= maxRetries) {
          // WHY: If cache exists, use it even if download failed after all retries
          if (await cacheFile.exists()) {
            LoggerService.warning(
              '[DataInit] Download failed after $maxRetries attempts, using cached file: $filename',
            );
            return cacheFile.readAsBytes();
          }
          rethrow;
        }
        // WHY: Exponential backoff: 2s, 4s, 8s
        final delayMs = 2000 * (1 << (retryCount - 1));
        LoggerService.warning(
          '[DataInit] Download failed for $filename (attempt $retryCount/$maxRetries), retrying in ${delayMs}ms: $error',
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }
    // This should never be reached, but Dart requires a return
    throw StateError('Retry loop completed without returning');
  }

  @visibleForTesting
  Future<void> runSummaryAggregationForTesting() => _aggregateDataForSummary();

  // WHY: Get the database file path to pass to isolate
  // The database is stored in application documents directory
  Future<String> _getDatabasePath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'medicaments.db');
  }

  // WHY: Aggregate data for MedicamentSummary table using SQL
  // This replaces the complex Dart-based ETL logic with a single SQL query
  Future<void> _aggregateDataForSummary() async {
    LoggerService.info(
      '[DataInit] Starting data aggregation for MedicamentSummary table.',
    );

    // WHY: Use SQL aggregation directly - no isolate needed
    // All aggregation happens in SQLite engine, which is faster and uses less memory
    final recordCount = await _db.databaseDao.populateSummaryTable();
    await _db.databaseDao.populateFts5Index();

    LoggerService.db(
      'Aggregated $recordCount records into MedicamentSummary table using SQL aggregation.',
    );
  }
}

// WHY: Static function to open database in isolate
// Must be top-level or static to be sendable to isolate
// Still needed for _parseAndInsertDataInBackground
Future<AppDatabase> _openDatabaseInIsolate(
  String dbPath,
  String tempPath,
) async {
  final file = File(dbPath);

  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }

  sqlite3.tempDirectory = tempPath;

  final database = NativeDatabase(file, setup: configureAppSQLite);
  return AppDatabase.forTesting(database);
}

// WHY: Helper function to insert data in chunks to reduce memory pressure
// Splits large lists into batches of AppConfig.batchSize and inserts each batch separately
Future<void> _insertChunked<T>(
  AppDatabase db,
  void Function(Batch batch, List<T> chunk, InsertMode mode) inserter,
  Iterable<T> items, {
  InsertMode mode = InsertMode.insert,
}) async {
  final itemsList = items.toList();
  if (itemsList.isEmpty) return;

  // Process in chunks to reduce memory usage
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

// WHY: Parse files and insert data entirely in isolate to avoid large data transfer
// Returns only counts/status instead of full data structures to minimize serialization overhead
Future<_ParseAndInsertResult> _parseAndInsertDataInBackground(
  ParseAndInsertArgs args,
) async {
  // WHY: Open database connection in isolate to avoid passing large data structures
  // Retry opening database connection to handle transient lock errors
  // WHY: Use longer delays between retries to allow main connection to fully release
  const maxDbOpenRetries = 8;
  var dbOpenRetryCount = 0;
  late AppDatabase db;
  while (dbOpenRetryCount < maxDbOpenRetries) {
    try {
      db = await _openDatabaseInIsolate(args.dbPath, args.tempPath);
      break;
    } catch (e) {
      dbOpenRetryCount++;
      if (dbOpenRetryCount >= maxDbOpenRetries) {
        rethrow;
      }
      // WHY: Exponential backoff with longer delays: 500ms, 1000ms, 2000ms, 4000ms, 8000ms, 16000ms, 32000ms
      final delayMs = 500 * (1 << (dbOpenRetryCount - 1));
      LoggerService.warning(
        '[DataInit] Failed to open database (attempt $dbOpenRetryCount/$maxDbOpenRetries), retrying in ${delayMs}ms: $e',
      );
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
  }

  // WHY: Skip clearing to avoid database lock conflicts
  // INSERT OR REPLACE mode (InsertMode.replace) will overwrite existing data automatically
  // This eliminates lock conflicts from DELETE operations

  Stream<String>? streamForKey(String key) =>
      BdpmFileParser.openLineStream(args.filePaths[key]);

  // Parse all files using BdpmFileParser static methods
  // Using Railway Oriented Programming with Either for explicit error handling
  final conditionsMap = await BdpmFileParser.parseConditions(
    streamForKey('conditions'),
  );
  final mitmMap = await BdpmFileParser.parseMitm(streamForKey('mitm'));

  final specialitesEither = await BdpmFileParser.parseSpecialites(
    streamForKey('specialites'),
    conditionsMap,
    mitmMap,
  );

  final specialitesResult = specialitesEither.fold((error) {
    LoggerService.error('[DataInit] Failed to parse specialites: $error');
    throw Exception('Failed to parse specialites: $error');
  }, (result) => result);

  final medicamentsEither = await BdpmFileParser.parseMedicaments(
    streamForKey('medicaments'),
    specialitesResult,
  );

  final medicamentsResult = medicamentsEither.fold((error) {
    LoggerService.error('[DataInit] Failed to parse medicaments: $error');
    throw Exception('Failed to parse medicaments: $error');
  }, (result) => result);

  final principesEither = await BdpmFileParser.parseCompositions(
    streamForKey('compositions'),
    medicamentsResult.cisToCip13,
  );

  final principes = principesEither.fold((error) {
    LoggerService.error('[DataInit] Failed to parse compositions: $error');
    throw Exception('Failed to parse compositions: $error');
  }, (result) => result);

  final generiqueEither = await BdpmFileParser.parseGeneriques(
    streamForKey('generiques'),
    medicamentsResult.cisToCip13,
    medicamentsResult.medicamentCips,
  );

  final generiqueResult = generiqueEither.fold((error) {
    LoggerService.error('[DataInit] Failed to parse generiques: $error');
    throw Exception('Failed to parse generiques: $error');
  }, (result) => result);

  final availabilityEither = await BdpmFileParser.parseAvailability(
    streamForKey('availability'),
    medicamentsResult.cisToCip13,
  );

  final availabilityRows = availabilityEither.fold((error) {
    LoggerService.error('[DataInit] Failed to parse availability: $error');
    throw Exception('Failed to parse availability: $error');
  }, (result) => result);

  // WHY: Wrap database operations in try/finally to ensure database is always closed
  // This prevents database locks from persisting after isolate completes
  try {
    // WHY: Insert data directly in isolate using chunked batch operations
    // This avoids serialization cost of passing large data structures to main thread
    // and prevents OOM on low-end devices by processing records in batches
    // WHY: Retry logic with exponential backoff to handle transient database lock errors
    const maxRetries = 5;
    var retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        // WHY: Process each table type independently with chunked insertion
        // This reduces memory pressure by inserting in smaller batches
        final specialitesCompanions = specialitesResult.specialites.map(
          (row) => drift_db.SpecialitesCompanion(
            cisCode: Value(row['cis_code'] as String),
            nomSpecialite: Value(row['nom_specialite'] as String),
            procedureType: Value(row['procedure_type'] as String),
            statutAdministratif: Value(row['statut_administratif'] as String?),
            formePharmaceutique: Value(row['forme_pharmaceutique'] as String?),
            voiesAdministration: Value(row['voies_administration'] as String?),
            etatCommercialisation: Value(
              row['etat_commercialisation'] as String?,
            ),
            titulaire: Value(row['titulaire'] as String?),
            conditionsPrescription: Value(
              row['conditions_prescription'] as String?,
            ),
            atcCode: Value(row['atc_code'] as String?),
            isSurveillance: Value(row['is_surveillance'] as bool? ?? false),
          ),
        );
        await _insertChunked(
          db,
          (batch, chunk, mode) =>
              batch.insertAll(db.specialites, chunk, mode: mode),
          specialitesCompanions,
          mode: InsertMode.replace,
        );

        final medicamentsCompanions = medicamentsResult.medicaments.map(
          (row) => drift_db.MedicamentsCompanion(
            codeCip: Value(row['code_cip'] as String),
            cisCode: Value(row['cis_code'] as String),
            presentationLabel: Value(row['presentation_label'] as String?),
            commercialisationStatut: Value(
              row['commercialisation_statut'] as String?,
            ),
            tauxRemboursement: Value(row['taux_remboursement'] as String?),
            prixPublic: Value(row['prix_public'] as double?),
            agrementCollectivites: Value(
              row['agrement_collectivites'] as String?,
            ),
          ),
        );
        await _insertChunked(
          db,
          (batch, chunk, mode) =>
              batch.insertAll(db.medicaments, chunk, mode: mode),
          medicamentsCompanions,
          mode: InsertMode.replace,
        );

        final principesCompanions = principes.map(
          (row) => drift_db.PrincipesActifsCompanion(
            codeCip: Value(row['code_cip'] as String),
            principe: Value(row['principe'] as String),
            dosage: Value(row['dosage'] as String?),
            dosageUnit: Value(row['dosage_unit'] as String?),
          ),
        );
        await _insertChunked(
          db,
          (batch, chunk, mode) =>
              batch.insertAll(db.principesActifs, chunk, mode: mode),
          principesCompanions,
        );

        final generiqueGroupsCompanions = generiqueResult.generiqueGroups.map(
          (row) => drift_db.GeneriqueGroupsCompanion(
            groupId: Value(row['group_id'] as String),
            libelle: Value(row['libelle'] as String),
          ),
        );
        await _insertChunked(
          db,
          (batch, chunk, mode) =>
              batch.insertAll(db.generiqueGroups, chunk, mode: mode),
          generiqueGroupsCompanions,
          mode: InsertMode.replace,
        );

        final groupMembersCompanions = generiqueResult.groupMembers.map(
          (row) => drift_db.GroupMembersCompanion(
            codeCip: Value(row['code_cip'] as String),
            groupId: Value(row['group_id'] as String),
            type: Value(row['type'] as int),
          ),
        );
        await _insertChunked(
          db,
          (batch, chunk, mode) =>
              batch.insertAll(db.groupMembers, chunk, mode: mode),
          groupMembersCompanions,
          mode: InsertMode.replace,
        );

        // Clear availability table before inserting new data
        await db.batch((batch) {
          batch.deleteWhere(
            db.medicamentAvailability,
            (_) => const Constant(true),
          );
        });

        if (availabilityRows.isNotEmpty) {
          final availabilityCompanions = availabilityRows.map(
            (row) => drift_db.MedicamentAvailabilityCompanion(
              codeCip: Value(row['code_cip'] as String),
              statut: Value(row['statut'] as String),
              dateDebut: Value(row['date_debut'] as DateTime?),
              dateFin: Value(row['date_fin'] as DateTime?),
              lien: Value(row['lien'] as String?),
            ),
          );
          await _insertChunked(
            db,
            (batch, chunk, mode) =>
                batch.insertAll(db.medicamentAvailability, chunk, mode: mode),
            availabilityCompanions,
            mode: InsertMode.replace,
          );
        }

        // Success - break out of retry loop
        break;
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          // Final attempt failed - rethrow the error
          rethrow;
        }
        // WHY: Exponential backoff with longer delays: 500ms, 1000ms, 2000ms, 4000ms, 8000ms
        final delayMs = 500 * (1 << (retryCount - 1));
        LoggerService.warning(
          '[DataInit] Database lock error (attempt $retryCount/$maxRetries), retrying in ${delayMs}ms: $e',
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }

    // WHY: Return only counts/status instead of full data structures
    return _ParseAndInsertResult(
      medicamentCount: medicamentsResult.medicaments.length,
      principeCount: principes.length,
      groupMemberCount: generiqueResult.groupMembers.length,
    );
  } finally {
    // WHY: Force close database connection to release SQLite locks
    // This ensures the main thread can proceed with aggregation without waiting indefinitely
    await db.close();
  }
}

// WHY: Result structure for isolate work - contains only counts/status
class _ParseAndInsertResult {
  const _ParseAndInsertResult({
    required this.medicamentCount,
    required this.principeCount,
    required this.groupMemberCount,
  });

  final int medicamentCount;
  final int principeCount;
  final int groupMemberCount;
}
