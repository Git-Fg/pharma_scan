import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/config/database_config.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';

enum InitializationStep { idle, downloading, ready, error }

/// Service for database initialization using a download-only workflow.
///
/// Flow: Version Check → Download → Decompress → Integrity Check → Update Preferences
class DataInitializationService {
  DataInitializationService({
    required AppDatabase database,
    required FileDownloadService fileDownloadService,
    required PreferencesService preferencesService,
    Dio? dio,
  }) : _db = database,
       _downloadService = fileDownloadService,
       _prefs = preferencesService,
       _dio = dio ?? _createDefaultDio();

  static const String dataVersion = 'remote-database';

  final AppDatabase _db;
  final FileDownloadService _downloadService;
  final PreferencesService _prefs;
  final Dio _dio;
  final _stepController = StreamController<InitializationStep>.broadcast();
  final _detailController = StreamController<String>.broadcast();

  Stream<InitializationStep> get onStepChanged => _stepController.stream;
  Stream<String> get onDetailChanged => _detailController.stream;

  void dispose() {
    if (!_stepController.isClosed) unawaited(_stepController.close());
    if (!_detailController.isClosed) unawaited(_detailController.close());
  }

  /// Initializes the database by downloading from GitHub if needed.
  Future<void> initializeDatabase({bool forceRefresh = false}) async {
    try {
      // 1. Check for existing data
      final hasData = await _db.catalogDao.hasExistingData();
      if (!forceRefresh && hasData) {
        await _db.checkDatabaseIntegrity();
        LoggerService.info('[DataInit] Database ready with existing data.');
        _emit(InitializationStep.ready, Strings.initializationReady);
        return;
      }

      LoggerService.info('[DataInit] Downloading database...');
      _emit(InitializationStep.downloading, 'Téléchargement de la base...');

      // 2. Build download URL from GitHub latest release
      final downloadUrl = await _resolveDownloadUrl();
      if (downloadUrl == null) {
        throw Exception('Could not resolve database download URL.');
      }

      // 3. Download compressed file
      final bytesEither = await _downloadService.downloadToBytes(downloadUrl);
      final compressedBytes = bytesEither.fold(
        ifLeft: (f) => throw Exception('Download failed: ${f.message}'),
        ifRight: (bytes) => bytes,
      );

      // 4. Decompress and replace database file
      await _decompressAndReplace(compressedBytes);

      // 5. Verify integrity
      await _db.checkDatabaseIntegrity();

      // 6. Save version tag
      await _prefs.setDbVersionTag(dataVersion);

      LoggerService.info('[DataInit] Initialization complete.');
      _emit(InitializationStep.ready, Strings.initializationReady);
    } catch (e, stackTrace) {
      LoggerService.error(
        '[DataInit] Error during initialization',
        e,
        stackTrace,
      );
      _emit(InitializationStep.error, Strings.initializationError);
      rethrow;
    }
  }

  Future<String?> _resolveDownloadUrl() async {
    // Build URL to the asset in latest GitHub release
    const baseUrl =
        'https://github.com/${DatabaseConfig.repoOwner}/'
        '${DatabaseConfig.repoName}/releases/latest/download/'
        '${DatabaseConfig.compressedDbFilename}';
    return baseUrl;
  }

  Future<void> _decompressAndReplace(List<int> compressedBytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, DatabaseConfig.dbFilename);

    // Decompress using GZip
    final decompressed = GZipCodec().decode(compressedBytes);

    // Close existing connection before replacing file
    await _db.close();

    // Clean WAL/SHM files
    await _cleanupWalFiles(dbPath);

    // Write new database file
    final dbFile = File(dbPath);
    if (await dbFile.exists()) await dbFile.delete();
    await dbFile.writeAsBytes(decompressed, flush: true);

    LoggerService.info('[DataInit] Database file replaced.');
  }

  Future<void> _cleanupWalFiles(String dbPath) async {
    for (final suffix in ['-wal', '-shm']) {
      final file = File('$dbPath$suffix');
      if (await file.exists()) await file.delete();
    }
  }

  void _emit(InitializationStep step, String detail) {
    if (!_stepController.isClosed) _stepController.add(step);
    if (!_detailController.isClosed) _detailController.add(detail);
  }

  /// Creates a default Dio instance for GitHub API calls
  static Dio _createDefaultDio() {
    return Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
  }

  /// Public method to update the database from GitHub Releases
  ///
  /// Returns `true` if an update was performed, `false` if no update was needed
  /// or if the update failed. This method can be called by SyncController
  /// or any other service that needs to trigger a database update.
  Future<bool> updateDatabase({bool force = false}) async {
    try {
      LoggerService.info('[DataInit] Checking for database updates...');

      // 1. Get latest release info from GitHub API
      final response = await _dio.get<Map<String, dynamic>>(
        DatabaseConfig.githubReleasesUrl,
        options: Options(responseType: ResponseType.json),
      );

      if (response.statusCode != 200 || response.data == null) {
        LoggerService.warning(
          '[DataInit] GitHub API error: ${response.statusCode}',
        );
        return false;
      }

      final json = response.data!;
      final latestTag = json['tag_name'] as String;

      // 2. Find the download URL for reference.db.gz asset
      final assets = json['assets'] as List<dynamic>;
      final asset = assets.firstWhere(
        (a) =>
            (a as Map<String, dynamic>)['name'] ==
            DatabaseConfig.compressedDbFilename,
        orElse: () => null,
      );

      if (asset == null) {
        LoggerService.warning(
          '[DataInit] Asset ${DatabaseConfig.compressedDbFilename} not found in release',
        );
        return false;
      }

      final downloadUrl =
          (asset as Map<String, dynamic>)['browser_download_url'] as String;

      // 3. Check if update is needed
      if (!force) {
        final currentTag = _prefs.getDbVersionTag();

        if (currentTag == latestTag) {
          LoggerService.info(
            '[DataInit] Database is up to date ($currentTag)',
          );
          return false;
        }

        LoggerService.info(
          '[DataInit] New version available: $latestTag (current: $currentTag)',
        );
      }

      // 4. Perform the update
      LoggerService.info('[DataInit] Starting database update...');
      _emit(InitializationStep.downloading, 'Mise à jour de la base...');

      // Download compressed file using FileDownloadService
      final bytesEither = await _downloadService.downloadToBytes(downloadUrl);
      final compressedBytes = bytesEither.fold(
        ifLeft: (f) => throw Exception('Download failed: ${f.message}'),
        ifRight: (bytes) => bytes,
      );

      // Decompress and replace database file
      await _decompressAndReplace(compressedBytes);

      // Verify integrity
      await _db.checkDatabaseIntegrity();

      // Save the new version tag
      await _prefs.setDbVersionTag(latestTag);

      LoggerService.info('[DataInit] Database update completed successfully');
      _emit(InitializationStep.ready, Strings.initializationReady);
      return true;
    } on TimeoutException catch (e) {
      LoggerService.warning('[DataInit] Timeout during update: $e');
      return false;
    } on Exception catch (e, stackTrace) {
      LoggerService.error(
        '[DataInit] Error during database update',
        e,
        stackTrace,
      );
      _emit(InitializationStep.error, Strings.initializationError);
      return false;
    }
  }
}
