// lib/core/services/data_initialization_service.dart
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
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
  bool clearTables,
});

enum InitializationStep {
  idle,
  downloading,
  parsing,
  aggregating,
  cleaning,
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
      '2025-01-20-rc3'; // Updated to force FTS5 re-indexing with trigram tokenizer and sanitized principles
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
      final filePaths = await _downloadAllFilesWithCacheCheck();

      _stepController.add(InitializationStep.parsing);
      await _parseAndInsertData(filePaths, clearTables: true);

      _stepController.add(InitializationStep.aggregating);
      // WHY: Add delay before aggregation to ensure isolate database operations complete
      // This helps prevent "database is locked" errors when main thread tries to aggregate
      await Future.delayed(const Duration(milliseconds: 500));
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

    // WHY: Download only missing files
    final downloadTasks = missingFiles.map((entry) async {
      LoggerService.info(
        '[DataInit] Downloading ${entry.key} from ${entry.value}',
      );
      final path = await _getFilePath(entry.key, entry.value);
      LoggerService.info('[DataInit] Downloaded ${entry.key} to $path');
      return MapEntry(entry.key, path);
    });
    final downloadedEntries = await Future.wait(downloadTasks);

    // WHY: Combine cached and downloaded files
    return {...cachedFiles, ...Map.fromEntries(downloadedEntries)};
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

  Future<void> _parseAndInsertData(
    Map<String, String> filePaths, {
    bool clearTables = true,
  }) async {
    LoggerService.info(
      '[DataInit] Parsing BDPM files: ${filePaths.keys.join(', ')}. '
      'clearTables: $clearTables',
    );

    // WHY: Pass only database path and temp path to isolate (~1KB) instead of large data structures
    // Parsing and batch insertion happen entirely inside the isolate
    // WHY: Skip clearing to avoid database lock conflicts - INSERT OR REPLACE will overwrite existing data
    // This eliminates the need for separate DELETE operations that cause lock conflicts
    // WHY: Longer delay and ensure database connection is released before isolate starts
    // This helps prevent "database is locked" errors when isolate tries to open the database
    // WHY: Multiple delays to ensure all database operations complete and connections are released
    // WHY: Force multiple event loop ticks to allow any pending database operations to complete
    await Future.delayed(const Duration(milliseconds: 100));
    await Future.delayed(const Duration(milliseconds: 200));
    await Future.delayed(const Duration(milliseconds: 300));

    final dbPath = await _getDatabasePath();
    final tempPath = (await getTemporaryDirectory()).path;
    final args = (
      dbPath: dbPath,
      tempPath: tempPath,
      filePaths: filePaths,
      clearTables: false,
    );

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
        await Future.delayed(Duration(milliseconds: delayMs));
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

  // WHY: Enable WAL mode to support concurrent access from main isolate
  // This prevents "database is locked" exceptions when background isolate
  // performs parsing while main isolate reads/writes
  // WHY: Set busy timeout to allow retries when database is locked
  // This gives SQLite time to wait for locks to be released instead of failing immediately
  final database = NativeDatabase(file);
  final appDb = AppDatabase.forTesting(database);
  await appDb.customStatement('PRAGMA journal_mode=WAL');
  await appDb.customStatement('PRAGMA busy_timeout=30000'); // 30 second timeout
  return appDb;
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
      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }

  // WHY: Skip clearing to avoid database lock conflicts
  // INSERT OR REPLACE mode (InsertMode.replace) will overwrite existing data automatically
  // This eliminates lock conflicts from DELETE operations

  // Helper to read file inside isolate
  String? readFileInIsolate(String? path) {
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    final bytes = file.readAsBytesSync();
    return BdpmFileParser.decodeContent(bytes);
  }

  // Parse all files using BdpmFileParser static methods
  final conditionsMap = BdpmFileParser.parseConditions(
    readFileInIsolate(args.filePaths['conditions']),
  );
  final mitmMap = BdpmFileParser.parseMitm(
    readFileInIsolate(args.filePaths['mitm']),
  );
  final specialitesResult = BdpmFileParser.parseSpecialites(
    readFileInIsolate(args.filePaths['specialites']),
    conditionsMap,
    mitmMap,
  );

  final medicamentsResult = BdpmFileParser.parseMedicaments(
    readFileInIsolate(args.filePaths['medicaments']),
    specialitesResult,
  );

  final principes = BdpmFileParser.parseCompositions(
    readFileInIsolate(args.filePaths['compositions']),
    medicamentsResult.cisToCip13,
  );

  final generiqueResult = BdpmFileParser.parseGeneriques(
    readFileInIsolate(args.filePaths['generiques']),
    medicamentsResult.cisToCip13,
    medicamentsResult.medicamentCips,
  );
  final availabilityRows = BdpmFileParser.parseAvailability(
    readFileInIsolate(args.filePaths['availability']),
    medicamentsResult.cisToCip13,
  );

  // WHY: Wrap database operations in try/finally to ensure database is always closed
  // This prevents database locks from persisting after isolate completes
  try {
    // WHY: Insert data directly in isolate using batch operations
    // This avoids serialization cost of passing large data structures to main thread
    // WHY: Retry logic with exponential backoff to handle transient database lock errors
    const maxRetries = 5;
    var retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        await db.batch((batch) {
          batch.insertAll(
            db.specialites,
            specialitesResult.specialites.map(
              (row) => drift_db.SpecialitesCompanion(
                cisCode: Value(row['cis_code'] as String),
                nomSpecialite: Value(row['nom_specialite'] as String),
                procedureType: Value(row['procedure_type'] as String),
                statutAdministratif: Value(
                  row['statut_administratif'] as String?,
                ),
                formePharmaceutique: Value(
                  row['forme_pharmaceutique'] as String?,
                ),
                voiesAdministration: Value(
                  row['voies_administration'] as String?,
                ),
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
            ),
            mode: InsertMode.replace,
          );
          batch.insertAll(
            db.medicaments,
            medicamentsResult.medicaments.map(
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
            ),
            mode: InsertMode.replace,
          );
          batch.insertAll(
            db.principesActifs,
            principes.map(
              (row) => drift_db.PrincipesActifsCompanion(
                codeCip: Value(row['code_cip'] as String),
                principe: Value(row['principe'] as String),
                dosage: Value(row['dosage'] as String?),
                dosageUnit: Value(row['dosage_unit'] as String?),
              ),
            ),
          );
          batch.insertAll(
            db.generiqueGroups,
            generiqueResult.generiqueGroups.map(
              (row) => drift_db.GeneriqueGroupsCompanion(
                groupId: Value(row['group_id'] as String),
                libelle: Value(row['libelle'] as String),
              ),
            ),
            mode: InsertMode.replace,
          );
          batch.insertAll(
            db.groupMembers,
            generiqueResult.groupMembers.map(
              (row) => drift_db.GroupMembersCompanion(
                codeCip: Value(row['code_cip'] as String),
                groupId: Value(row['group_id'] as String),
                type: Value(row['type'] as int),
              ),
            ),
            mode: InsertMode.replace,
          );
          batch.deleteWhere(
            db.medicamentAvailability,
            (_) => const Constant(true),
          );
          if (availabilityRows.isNotEmpty) {
            batch.insertAll(
              db.medicamentAvailability,
              availabilityRows.map(
                (row) => drift_db.MedicamentAvailabilityCompanion(
                  codeCip: Value(row['code_cip'] as String),
                  statut: Value(row['statut'] as String),
                  dateDebut: Value(row['date_debut'] as DateTime?),
                  dateFin: Value(row['date_fin'] as DateTime?),
                  lien: Value(row['lien'] as String?),
                ),
              ),
              mode: InsertMode.replace,
            );
          }
        });
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
        await Future.delayed(Duration(milliseconds: delayMs));
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
