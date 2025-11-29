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
    final versionEither = await _db.settingsDao.getBdpmVersion();
    final persistedVersion = versionEither.fold(
      ifLeft: (_) => null,
      ifRight: (v) => v,
    );

    final hasDataEither = await _db.libraryDao.hasExistingData();
    final hasExistingData = hasDataEither.fold(
      ifLeft: (_) => false,
      ifRight: (v) => v,
    );

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
      _stepController.add(InitializationStep.downloading);

      Map<String, String> filePaths;
      try {
        filePaths = await _downloadAllFilesWithCacheCheck();
      } catch (e, stackTrace) {
        LoggerService.warning(
          '[DataInit] Download failed, checking for existing database data: $e',
        );
        final hasDataEither = await _db.libraryDao.hasExistingData();
        final hasExistingData = hasDataEither.fold(
          ifLeft: (_) => false,
          ifRight: (v) => v,
        );
        if (hasExistingData) {
          LoggerService.info(
            '[DataInit] Using existing database data despite download failure. '
            'App will continue with cached data.',
          );
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
        rethrow;
      }

      _stepController.add(InitializationStep.parsing);
      await _parseAndInsertData(filePaths);

      _stepController.add(InitializationStep.aggregating);
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

  Future<void> _parseAndInsertData(Map<String, String> filePaths) async {
    LoggerService.info(
      '[DataInit] Parsing BDPM files: ${filePaths.keys.join(', ')}.',
    );

    //
    // CRITICAL: SQLite isolate locking on Android
    // On Android, SQLite uses file-level locking. When the main isolate has an open database connection,
    // the background isolate cannot open the same database file, resulting in "database is locked" errors.
    // These delays ensure all database operations in the main isolate complete and connections are fully
    // released before the background isolate attempts to open the database.
    //
    // DO NOT REMOVE OR REDUCE THESE DELAYS - they are essential for preventing database lock conflicts
    // on Android devices. The total delay (600ms) is minimal compared to the parsing time (seconds).
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

    const maxRetries = 3;
    var retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        return await _fileDownloadService.downloadToBytesWithCacheFallback(
          url: url,
          cacheFile: cacheFile,
        );
      } catch (error) {
        retryCount++;
        if (retryCount >= maxRetries) {
          if (await cacheFile.exists()) {
            LoggerService.warning(
              '[DataInit] Download failed after $maxRetries attempts, using cached file: $filename',
            );
            return cacheFile.readAsBytes();
          }
          rethrow;
        }
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

  Future<String> _getDatabasePath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'medicaments.db');
  }

  Future<void> _aggregateDataForSummary() async {
    LoggerService.info(
      '[DataInit] Starting data aggregation for MedicamentSummary table.',
    );

    final recordCount = await _db.databaseDao.populateSummaryTable();
    await _db.databaseDao.populateFts5Index();

    LoggerService.db(
      'Aggregated $recordCount records into MedicamentSummary table using SQL aggregation.',
    );
  }
}

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

Future<_ParseAndInsertResult> _parseAndInsertDataInBackground(
  ParseAndInsertArgs args,
) async {
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
      final delayMs = 500 * (1 << (dbOpenRetryCount - 1));
      LoggerService.warning(
        '[DataInit] Failed to open database (attempt $dbOpenRetryCount/$maxDbOpenRetries), retrying in ${delayMs}ms: $e',
      );
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
  }

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

  final specialitesResult = specialitesEither.fold(
    ifLeft: (error) {
      LoggerService.error('[DataInit] Failed to parse specialites: $error');
      throw Exception('Failed to parse specialites: $error');
    },
    ifRight: (result) => result,
  );

  final medicamentsEither = await BdpmFileParser.parseMedicaments(
    streamForKey('medicaments'),
    specialitesResult,
  );

  final medicamentsResult = medicamentsEither.fold(
    ifLeft: (error) {
      LoggerService.error('[DataInit] Failed to parse medicaments: $error');
      throw Exception('Failed to parse medicaments: $error');
    },
    ifRight: (result) => result,
  );

  final principesEither = await BdpmFileParser.parseCompositions(
    streamForKey('compositions'),
    medicamentsResult.cisToCip13,
  );

  final principes = principesEither.fold(
    ifLeft: (error) {
      LoggerService.error('[DataInit] Failed to parse compositions: $error');
      throw Exception('Failed to parse compositions: $error');
    },
    ifRight: (result) => result,
  );

  final generiqueEither = await BdpmFileParser.parseGeneriques(
    streamForKey('generiques'),
    medicamentsResult.cisToCip13,
    medicamentsResult.medicamentCips,
  );

  final generiqueResult = generiqueEither.fold(
    ifLeft: (error) {
      LoggerService.error('[DataInit] Failed to parse generiques: $error');
      throw Exception('Failed to parse generiques: $error');
    },
    ifRight: (result) => result,
  );

  final availabilityEither = await BdpmFileParser.parseAvailability(
    streamForKey('availability'),
    medicamentsResult.cisToCip13,
  );

  final availabilityRows = availabilityEither.fold(
    ifLeft: (error) {
      LoggerService.error('[DataInit] Failed to parse availability: $error');
      throw Exception('Failed to parse availability: $error');
    },
    ifRight: (result) => result,
  );

  try {
    const maxRetries = 5;
    var retryCount = 0;
    while (retryCount < maxRetries) {
      try {
        final specialitesCompanions = specialitesResult.specialites.map(
          (row) => SpecialitesCompanion(
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
          (row) => MedicamentsCompanion(
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
          (row) => PrincipesActifsCompanion(
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
          (row) => GeneriqueGroupsCompanion(
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
          (row) => GroupMembersCompanion(
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
            (row) => MedicamentAvailabilityCompanion(
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
        final delayMs = 500 * (1 << (retryCount - 1));
        LoggerService.warning(
          '[DataInit] Database lock error (attempt $retryCount/$maxRetries), retrying in ${delayMs}ms: $e',
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }

    return _ParseAndInsertResult(
      medicamentCount: medicamentsResult.medicaments.length,
      principeCount: principes.length,
      groupMemberCount: generiqueResult.groupMembers.length,
    );
  } finally {
    await db.close();
  }
}

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
