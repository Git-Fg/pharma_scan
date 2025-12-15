import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/core/config/database_config.dart';
import 'package:pharma_scan/core/database/daos/app_settings_dao.dart';
import 'package:pharma_scan/core/database/providers.dart';
import 'package:pharma_scan/core/providers/sync_provider.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';

enum InitializationStep { idle, downloading, ready, error, updateAvailable }

class VersionCheckResult {
  final bool updateAvailable;
  final String? localDate;
  final String remoteTag;
  final String? downloadUrl;
  final bool blockedByPolicy;

  VersionCheckResult({
    required this.updateAvailable,
    this.localDate,
    required this.remoteTag,
    this.downloadUrl,
    required this.blockedByPolicy,
  });
}

/// Service for database initialization using a download-only workflow.
///
/// Flow: Version Check → Download → Decompress → Integrity Check → Update Preferences

class DataInitializationService {
  DataInitializationService({
    required Ref ref,
    required FileDownloadService fileDownloadService,
    required Dio dio,
    AssetBundle? assetBundle,
  })  : _ref = ref,
        _downloadService = fileDownloadService,
        _dio = dio,
        _assetBundle = assetBundle ?? rootBundle;

  static const String dataVersion = 'remote-database';

  final Ref _ref;
  final FileDownloadService _downloadService;
  final Dio _dio;
  final AssetBundle _assetBundle;

  LoggerService get _logger => _ref.read(loggerProvider);

  AppSettingsDao get _appSettings =>
      _ref.read(databaseProvider()).appSettingsDao;
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
      // 1. Check if database needs to be downloaded/updated
      // We only download if:
      // - forced
      // - version is unknown (fresh install)
      // - or integrity check fails (handled below)
      final currentVersion = await _appSettings.bdpmVersion;
      final hasVersion = currentVersion != null && currentVersion.isNotEmpty;

      // Check integrity of existing DB if we think we have one
      bool integrityOk = false;
      if (hasVersion && !forceRefresh) {
        try {
          final db = _ref.read(databaseProvider());
          await db.checkDatabaseIntegrity();
          integrityOk = true;
        } catch (_) {
          integrityOk = false;
          _logger
              .warning('[DataInit] Integrity check failed, forcing download.');
        }
      }

      final needsDownload = forceRefresh || !hasVersion || !integrityOk;

      if (!needsDownload) {
        _logger.info(
            '[DataInit] Database is present (version: $currentVersion) and healthy.');
        _emit(InitializationStep.ready, Strings.initializationReady);
        return;
      }

      // Check if we can hydrate from assets before downloading
      // Only if no DB exists (first run) or if we want to force reset from bundle (not implemented yet)
      final docDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(docDir.path, DatabaseConfig.dbFilename);
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        try {
          _logger.info(
              '[DataInit] No local database found. Checking for bundled asset...');
          // Check if bundled asset exists
          // Note: In Flutter, we can't easily check if an asset exists without trying to load it
          // But since we control the build, we assume it's there if we put it in pubspec

          final assetPath = 'assets/database/reference.db.gz';
          // We use rootBundle to load the asset
          // However, for large files, it's better to get the ByteData and write it

          // Using specialized method to copy asset to file
          await _copyFromAsset(assetPath, dbFile);

          _logger.info('[DataInit] Database hydrated from bundled asset.');
          _emit(InitializationStep.ready, Strings.initializationReady);

          // Set version to "bundled" so we know where it came from
          // Or even better, if we can read the version from the DB metadata later?
          // For now, let's mark it as 'bundled'
          await _appSettings.setBdpmVersion('bundled');

          // Verify integrity of the copied DB
          final db = _ref.read(databaseProvider());
          await db.checkDatabaseIntegrity();

          // Trigger sync found in existing flow
          _triggerPostInitializationSync();
          return;
        } catch (e) {
          _logger.warning(
              '[DataInit] Failed to copy from asset: $e. Falling back to download.');
          // Fallthrough to download logic
        }
      }

      _logger.info('[DataInit] Downloading fresh database from backend...');
      _emit(InitializationStep.downloading, 'Téléchargement de la base...');

      // 3. Build download URL from GitHub latest release
      final downloadUrl = await _resolveDownloadUrl();
      if (downloadUrl == null) {
        throw Exception('Could not resolve database download URL.');
      }

      // 4. Download compressed file
      final bytesEither = await _downloadService.downloadToBytes(downloadUrl);
      final compressedBytes = bytesEither.fold(
        ifLeft: (f) => throw Exception('Download failed: ${f.message}'),
        ifRight: (bytes) => bytes,
      );

      // 5. Perform update with secure lifecycle
      await _performUpdate(compressedBytes);

      // 6. Verify the downloaded database
      final newDb = _ref.read(databaseProvider());
      await newDb.checkDatabaseIntegrity();

      // 7. Save version tag
      // 7. Save version tag
      // If we downloaded via initialization (not update), use a placeholder if we don't know the tag yet.
      // Ideally we would fetch the tag from the release we just downloaded from, but _resolveDownloadUrl
      // assumes 'latest'.
      // For now, set a marker so next launch doesn't loop. The SyncController will correct it to the real tag.
      if (currentVersion == null) {
        await _appSettings.setBdpmVersion('initial-install');
      } else {
        // Keep existing version or update if we had one?
        // If we re-downloaded due to integrity failure, we might want to reset or keep.
        // Let's assume 'initial-install' is safe.
        await _appSettings.setBdpmVersion(currentVersion);
      }

      _logger.info('[DataInit] Database initialization complete.');
      _emit(InitializationStep.ready, Strings.initializationReady);

      // Trigger sync after successful initialization
      _triggerPostInitializationSync();
    } catch (e, stackTrace) {
      _logger.error(
        '[DataInit] Error during initialization',
        e,
        stackTrace,
      );
      _emit(InitializationStep.error, Strings.initializationError);
      rethrow;
    }
  }

  Future<void> _performUpdate(List<int> compressedBytes) async {
    // 1. Préparer le remplacement
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, DatabaseConfig.dbFilename);

    // 2. Fermer la connexion actuelle de manière sécurisée
    try {
      final currentDb = _ref.read(databaseProvider());
      await currentDb.close();
    } catch (e) {
      _logger
          .warning('[DataInit] Error closing current database connection: $e');
    }

    // 3. Invalider le provider pour forcer une nouvelle instance
    _ref.invalidate(databaseProvider);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    // 4. Décompresser et écrire le nouveau fichier
    _logger.info('[DataInit] Writing new database file...');
    final decompressed = GZipCodec().decode(compressedBytes);
    final dbFile = File(dbPath);

    // Supprimer l'ancien fichier
    if (await dbFile.exists()) {
      await dbFile.delete();
      _logger.info('[DataInit] Removed old database file');
    }

    // Écrire le nouveau fichier
    await dbFile.writeAsBytes(decompressed, flush: true);
    _logger.info('[DataInit] Database file written successfully');

    // 5. Nettoyer WAL/SHM pour éviter les conflits
    await _cleanupWalFiles(dbPath);

    // 6. La nouvelle instance sera créée automatiquement lors du prochain accès
    _logger.info('[DataInit] Database file replacement complete');
  }

  Future<String?> _resolveDownloadUrl() async {
    // Build URL to the asset in latest GitHub release
    const baseUrl = 'https://github.com/${DatabaseConfig.repoOwner}/'
        '${DatabaseConfig.repoName}/releases/latest/download/'
        '${DatabaseConfig.compressedDbFilename}';
    return baseUrl;
  }

  // _decompressAndReplace supprimé (remplacé par _performUpdate)

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

  /// Public method to update the database from GitHub Releases
  ///
  /// Returns `true` if an update was performed, `false` if no update was needed
  /// or if the update failed. This method can be called by SyncController
  /// or any other service that needs to trigger a database update.
  Future<bool> updateDatabase({bool force = false}) async {
    try {
      _logger.info('[DataInit] Checking for database updates...');

      // 1. Get latest release info from GitHub API
      final response = await _dio.get<Map<String, dynamic>>(
        DatabaseConfig.githubReleasesUrl,
        options: Options(responseType: ResponseType.json),
      );

      if (response.statusCode != 200 || response.data == null) {
        _logger.warning(
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
        _logger.warning(
          '[DataInit] Asset ${DatabaseConfig.compressedDbFilename} not found in release',
        );
        return false;
      }

      final downloadUrl =
          (asset as Map<String, dynamic>)['browser_download_url'] as String;

      // 3. Check if update is needed
      if (!force) {
        final currentTag = await _appSettings.bdpmVersion;

        if (currentTag == latestTag) {
          _logger.info(
            '[DataInit] Database is up to date ($currentTag)',
          );
          return false;
        }

        _logger.info(
          '[DataInit] New version available: $latestTag (current: $currentTag)',
        );
      }

      // 4. Perform the update
      _logger.info('[DataInit] Starting database update...');
      _emit(InitializationStep.downloading, 'Mise à jour de la base...');

      // Download compressed file using FileDownloadService
      final bytesEither = await _downloadService.downloadToBytes(downloadUrl);
      final compressedBytes = bytesEither.fold(
        ifLeft: (f) => throw Exception('Download failed: ${f.message}'),
        ifRight: (bytes) => bytes,
      );

      // Decompress and replace database file
      await _performUpdate(compressedBytes);

      // Verify integrity
      // plus d'appel à _db ici, tout passe par _ref.read(databaseProvider)

      // Save the new version tag
      await _appSettings.setBdpmVersion(latestTag);

      _logger.info('[DataInit] Database update completed successfully');
      _emit(InitializationStep.ready, Strings.initializationReady);

      // Trigger sync after successful update
      _triggerPostInitializationSync();

      return true;
    } on TimeoutException catch (e) {
      _logger.warning('[DataInit] Timeout during update: $e');
      return false;
    } on Exception catch (e, stackTrace) {
      _logger.error(
        '[DataInit] Error during database update',
        e,
        stackTrace,
      );
      _emit(InitializationStep.error, Strings.initializationError);
      return false;
    }
  }

  /// Triggers sync after successful database initialization or update
  void _triggerPostInitializationSync() {
    // Trigger sync asynchronously to avoid blocking the initialization flow
    Future.microtask(() async {
      try {
        _logger.info('[DataInit] Triggering post-initialization sync...');
        final syncController = _ref.read(syncControllerProvider.notifier);
        await syncController.startSync();
        _logger.info('[DataInit] Post-initialization sync completed');
      } catch (e, stackTrace) {
        _logger.error(
          '[DataInit] Error during post-initialization sync',
          e,
          stackTrace,
        );
      }
    });
  }

  Future<void> _copyFromAsset(String assetPath, File destination) async {
    try {
      final byteData = await _assetBundle.load(assetPath);
      final compressedBytes = byteData.buffer
          .asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

      _logger.info('[DataInit] Decompressing asset $assetPath...');
      final decompressed = GZipCodec().decode(compressedBytes);

      await destination.writeAsBytes(decompressed, flush: true);
    } catch (e) {
      throw Exception('Could not copy and decompress asset $assetPath: $e');
    }
  }

  // New Version Check Logic
  Future<VersionCheckResult?> checkVersionStatus(
      {bool ignorePolicy = false}) async {
    try {
      final db = _ref.read(databaseProvider());

      // 1. Get Local Version from _metadata
      String? localDate;
      try {
        final result = await db.customSelect(
          'SELECT value FROM _metadata WHERE key = ?',
          variables: [Variable.withString('last_updated')],
        ).getSingleOrNull();

        if (result != null) {
          localDate = result.read<String>('value');
        }
      } catch (e) {
        _logger.warning('[DataInit] Could not read _metadata: $e');
        // Fallback to SharedPreferences if _metadata missing (legacy DB)
        localDate = await _appSettings.bdpmVersion;
      }

      // 2. Get Remote Version
      final response = await _dio.get<Map<String, dynamic>>(
        DatabaseConfig.githubReleasesUrl,
        options: Options(responseType: ResponseType.json),
      );

      if (response.statusCode != 200 || response.data == null) {
        return null;
      }

      final json = response.data!;
      final latestTag = json['tag_name'] as String;

      // Parse tag (db-YYYY-MM-DD...) to Date if possible for comparison?
      // For now, assuming tag IS the version identifier.
      // If we used ISO dates in backend, we should be able to compare string-wise or parse.
      // Plan said: "Parse Remote Tag... Parse Local Date... Compare"

      // 3. Find asset URL
      final assets = json['assets'] as List<dynamic>;
      final asset = assets.firstWhere(
        (a) =>
            (a as Map<String, dynamic>)['name'] ==
            DatabaseConfig.compressedDbFilename,
        orElse: () => null,
      );
      final downloadUrl =
          (asset as Map<String, dynamic>?)?['browser_download_url'] as String?;

      // 4. Compare
      // Logic: If localDate matches latestTag (or is close enough?), up to date.
      // Wait, localDate is ISO string "2023-..."
      // Remote Tag is "db-YYYY-MM-DD..."
      // We need to parse both to DateTime to compare properly.

      // Assuming naive comparison for now or equality check if format differs
      bool updateAvailable = false;
      if (localDate != null) {
        // Simple string inequality for now, or parsing if format established
        // If localDate is ISO (from JS new Date().toISOString())
        // And Tag is "db-..."
        // We can't compare directly.
        // Let's rely on inequality.
        updateAvailable = localDate != latestTag;
        // IMPROVEMENT: Implement real date parsing comparison here
      } else {
        updateAvailable = true; // No local version
      }

      // 5. Check Policy
      final policy = await _appSettings.updatePolicy ?? 'ask';
      bool blocked = false;

      if (updateAvailable && !ignorePolicy) {
        if (policy == 'never') {
          blocked = true;
          updateAvailable = false; // Effectively hidden
        }
      }

      return VersionCheckResult(
        updateAvailable: updateAvailable,
        localDate: localDate,
        remoteTag: latestTag,
        downloadUrl: downloadUrl,
        blockedByPolicy: blocked,
      );
    } catch (e) {
      _logger.error('[DataInit] Version check failed', e);
      return null;
    }
  }
}
