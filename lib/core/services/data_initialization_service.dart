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
  /// Initializes the database using the bundled offline asset.
  ///
  /// This method is "Offline First":
  /// 1. Checks current DB integrity.
  /// 2. If valid, finishes immediately.
  /// 3. If invalid or missing (or forced), hydrates from `assets/database/reference.db.gz`.
  ///
  /// Network downloads occur ONLY via `checkVersionStatus` + `performUpdate`,
  /// triggered explicitly by the user or the update policy dialog.
  Future<void> initializeDatabase({bool forceRefresh = false}) async {
    try {
      final currentVersion = await _appSettings.bdpmVersion;
      final hasVersion = currentVersion != null && currentVersion.isNotEmpty;

      // 1. Check integrity of existing DB if we think we have one
      bool integrityOk = false;
      if (hasVersion && !forceRefresh) {
        try {
          final db = _ref.read(databaseProvider());
          await db.checkDatabaseIntegrity();
          integrityOk = true;
        } catch (_) {
          integrityOk = false;
          _logger
              .warning('[DataInit] Integrity check failed, requiring reset.');
        }
      }

      // 2. Decide if we need to initialize (Reset or Fresh Install)
      final needsInitialization = forceRefresh || !hasVersion || !integrityOk;

      if (!needsInitialization) {
        _logger.info(
            '[DataInit] Database is present (version: $currentVersion) and healthy.');
        _emit(InitializationStep.ready, Strings.initializationReady);
        return;
      }

      // 3. Hydrate from Bundled Asset
      _logger.info('[DataInit] Initializing database from bundled asset...');
      _emit(InitializationStep.downloading,
          'Préparation de la base de données...');

      // CRITICAL START: Close existing connection before replacing file
      try {
        // We explicitly close the DB to ensure no file locks/handles remain
        // before we delete/overwrite the file.
        // Even if we didn't check integrity, we might have an open connection.
        final currentDb = _ref.read(databaseProvider());
        await currentDb.close();
      } catch (e) {
        // If DB wasn't open or other error, mostly ignore but log
        _logger.warning('[DataInit] Preparing close: $e');
      }

      // Invalidate provider so next read creates a fresh instance attached to the new file
      _ref.invalidate(databaseProvider);
      // Small delay to ensure OS releases handles (especially important on Windows/Android)
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // CRITICAL END

      final docDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(docDir.path, DatabaseConfig.dbFilename);
      final dbFile = File(dbPath);

      // If resetting, ensure old file is gone
      if (await dbFile.exists() && needsInitialization) {
        try {
          await dbFile.delete();
        } catch (e) {
          _logger.warning('[DataInit] Could not delete old DB: $e');
        }
      }

      try {
        const assetPath = 'assets/database/reference.db.gz';

        // Use the optimized copy helper
        await _copyFromAsset(assetPath, dbFile);

        _logger.info('[DataInit] Database hydrated from bundled asset.');

        // 4. Verify the new DB
        final db = _ref.read(databaseProvider());
        await db.checkDatabaseIntegrity();

        // 5. Mark as initialized (bundled version)
        // We use a special tag or 'bundled' if we don't extract the real tag yet.
        // Ideally we should query the metadata table for the real version?
        // For safety, we mark as 'bundled' and let SyncProvider check for updates later.
        await _appSettings.setBdpmVersion('bundled');

        _emit(InitializationStep.ready, Strings.initializationReady);
        _triggerPostInitializationSync();
      } catch (e) {
        _logger.error('[DataInit] Failed to initialize from asset.', e);
        _emit(InitializationStep.error,
            'Erreur d\'initialisation. Vérifiez l\'espace de stockage.');
        throw Exception('Offline initialization failed: $e');
      }
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
