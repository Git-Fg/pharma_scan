import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/config/database_config.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';

enum InitializationStep { idle, downloading, ready, error }

/// Service for database initialization using a download-only workflow.
///
/// Flow: Version Check → Download → Decompress → Integrity Check → Update Preferences
class DataInitializationService {
  DataInitializationService({
    required AppDatabase database,
    required FileDownloadService fileDownloadService,
  }) : _db = database,
       _downloadService = fileDownloadService;

  static const String dataVersion = 'remote-database';

  final AppDatabase _db;
  final FileDownloadService _downloadService;
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
      await _db.settingsDao.setDbVersionTag(dataVersion);

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
    final baseUrl =
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
}
