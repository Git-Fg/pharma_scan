import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:pharma_scan/core/config/data_sources.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SyncPhase {
  idle,
  waitingNetwork,
  checking,
  downloading,
  applying,
  success,
  error,
}

class SyncProgress {
  const SyncProgress({required this.phase, this.message, this.progress});

  final SyncPhase phase;
  final String? message;
  final double? progress;

  SyncProgress copyWith({SyncPhase? phase, String? message, double? progress}) {
    return SyncProgress(
      phase: phase ?? this.phase,
      message: message ?? this.message,
      progress: progress ?? this.progress,
    );
  }
}

typedef UpdateFrequencyResolver = Future<UpdateFrequency> Function();
typedef SyncStatusReporter = void Function(SyncProgress progress);

class SyncService {
  SyncService({
    SharedPreferences? sharedPreferences,
    DataInitializationService? dataInitializationService,
    http.Client? httpClient,
    Future<bool> Function()? connectivityProbe,
    DateTime Function()? clock,
  }) : _preferences = sharedPreferences ?? sl<SharedPreferences>(),
       _dataInitializationService =
           dataInitializationService ?? sl<DataInitializationService>(),
       _httpClient = httpClient ?? http.Client(),
       _connectivityProbe = connectivityProbe,
       _clock = clock ?? DateTime.now;

  static const _lastCheckKey = 'sync_last_check_epoch_ms';
  static const _hashPrefix = 'sync_hash_';

  final SharedPreferences _preferences;
  final DataInitializationService _dataInitializationService;
  final http.Client _httpClient;
  final Future<bool> Function()? _connectivityProbe;
  final DateTime Function() _clock;

  bool _isRunning = false;

  Future<bool> checkForUpdates({
    required UpdateFrequencyResolver resolveFrequency,
    required SyncStatusReporter reportStatus,
    bool force = false,
  }) async {
    if (_isRunning) return false;

    final frequency = await resolveFrequency();
    if (!force && frequency == UpdateFrequency.none) {
      developer.log(
        'Sync skipped: disabled by user preference',
        name: 'SyncService',
      );
      return false;
    }

    final now = _clock();
    final lastCheck = _getLastCheckTime();
    if (!force &&
        lastCheck != null &&
        frequency.interval != Duration.zero &&
        now.difference(lastCheck) < frequency.interval) {
      developer.log(
        'Sync skipped: next check scheduled for '
        '${lastCheck.add(frequency.interval).toIso8601String()}',
        name: 'SyncService',
      );
      return false;
    }

    return _performSync(reportStatus);
  }

  Future<bool> _performSync(SyncStatusReporter reportStatus) async {
    _isRunning = true;
    try {
      reportStatus(
        const SyncProgress(
          phase: SyncPhase.waitingNetwork,
          message: 'Vérification de la connexion réseau…',
        ),
      );
      await _waitForConnectivity();

      reportStatus(
        const SyncProgress(
          phase: SyncPhase.checking,
          message: 'Analyse des fichiers officiels BDPM…',
        ),
      );

      var hasChanges = false;
      final sources = DataSources.files.entries.toList();

      for (var i = 0; i < sources.length; i++) {
        final entry = sources[i];
        reportStatus(
          SyncProgress(
            phase: SyncPhase.downloading,
            message: 'Téléchargement de ${entry.key}…',
            progress: (i + 1) / sources.length,
          ),
        );

        final tempFile = await _downloadFile(entry.value, entry.key);
        final hash = await _computeSha256(tempFile);
        final previousHash = _getSourceHash(entry.key);

        if (previousHash != hash) {
          hasChanges = true;
          await _setSourceHash(entry.key, hash);
        }

        await _safeDelete(tempFile);
      }

      if (hasChanges) {
        reportStatus(
          const SyncProgress(
            phase: SyncPhase.applying,
            message: 'Application des mises à jour locales…',
          ),
        );
        await _dataInitializationService.initializeDatabase(forceRefresh: true);
      }

      reportStatus(
        SyncProgress(
          phase: SyncPhase.success,
          message: hasChanges
              ? 'Base BDPM mise à jour avec succès.'
              : 'Aucun changement détecté.',
        ),
      );

      return hasChanges;
    } catch (error, stackTrace) {
      reportStatus(
        const SyncProgress(
          phase: SyncPhase.error,
          message: 'Synchronisation échouée. Réessayez plus tard.',
        ),
      );
      developer.log(
        'Sync failed',
        name: 'SyncService',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      await _setLastCheckTime(_clock());
      _scheduleReset(reportStatus);
      _isRunning = false;
    }
  }

  Future<void> _scheduleReset(SyncStatusReporter reportStatus) async {
    await Future<void>.delayed(const Duration(seconds: 3));
    reportStatus(const SyncProgress(phase: SyncPhase.idle));
  }

  Future<void> _waitForConnectivity() async {
    while (true) {
      final probe = _connectivityProbe;
      final hasConnectivity = probe != null
          ? await probe.call()
          : await _hasNetworkConnectivity();
      if (hasConnectivity) return;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  Future<bool> _hasNetworkConnectivity() async {
    try {
      final result = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<File> _downloadFile(String url, String key) async {
    final response = await _httpClient.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Téléchargement impossible pour $key');
    }
    final tempFile = File(
      '${Directory.systemTemp.path}/pharma_sync_${key}_${_clock().millisecondsSinceEpoch}.tmp',
    );
    await tempFile.writeAsBytes(response.bodyBytes);
    return tempFile;
  }

  Future<String> _computeSha256(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<void> _safeDelete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore failures: temp files may be cleaned later by OS.
    }
  }

  DateTime? _getLastCheckTime() {
    final millis = _preferences.getInt(_lastCheckKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> _setLastCheckTime(DateTime timestamp) async {
    await _preferences.setInt(_lastCheckKey, timestamp.millisecondsSinceEpoch);
  }

  String? _getSourceHash(String sourceKey) {
    return _preferences.getString('$_hashPrefix$sourceKey');
  }

  Future<void> _setSourceHash(String sourceKey, String hash) async {
    await _preferences.setString('$_hashPrefix$sourceKey', hash);
  }
}
