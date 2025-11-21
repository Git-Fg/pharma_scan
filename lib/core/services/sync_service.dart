import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pharma_scan/core/config/data_sources.dart';
import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/drift_database_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

enum SyncPhase {
  idle,
  waitingNetwork,
  checking,
  downloading,
  applying,
  success,
  error,
}

enum SyncStatusCode {
  idle,
  waitingNetwork,
  checkingUpdates,
  downloadingSource,
  applyingUpdate,
  successAlreadyCurrent,
  successUpdatesApplied,
  successVerified,
  error,
}

enum SyncErrorType { network, scraping, download, apply, unknown }

class SyncProgress {
  const SyncProgress({
    required this.phase,
    required this.code,
    this.progress,
    this.subject,
    this.errorType,
  });

  final SyncPhase phase;
  final SyncStatusCode code;
  final double? progress;
  final String? subject;
  final SyncErrorType? errorType;

  SyncProgress copyWith({
    SyncPhase? phase,
    SyncStatusCode? code,
    double? progress,
    String? subject,
    SyncErrorType? errorType,
  }) {
    return SyncProgress(
      phase: phase ?? this.phase,
      code: code ?? this.code,
      progress: progress ?? this.progress,
      subject: subject ?? this.subject,
      errorType: errorType ?? this.errorType,
    );
  }
}

typedef UpdateFrequencyResolver = Future<UpdateFrequency> Function();
typedef SyncStatusReporter = void Function(SyncProgress progress);

class SyncService {
  SyncService({
    required DriftDatabaseService databaseService,
    required DataInitializationService dataInitializationService,
    FileDownloadService? fileDownloadService,
    Dio? dio,
    Future<bool> Function()? connectivityProbe,
    DateTime Function()? clock,
  }) : _databaseService = databaseService,
       _dataInitializationService = dataInitializationService,
       _fileDownloadService = fileDownloadService ?? FileDownloadService(),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
               headers: const {'Accept': 'text/html,*/*'},
             ),
           ),
       _connectivityProbe = connectivityProbe,
       _clock = clock ?? DateTime.now;

  static const _updatePageUrl =
      'https://base-donnees-publique.medicaments.gouv.fr/telechargement';

  final DriftDatabaseService _databaseService;
  final DataInitializationService _dataInitializationService;
  final FileDownloadService _fileDownloadService;
  final Dio _dio;
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
      LoggerService.info('Sync skipped: disabled by user preference');
      return false;
    }

    final now = _clock();
    final lastCheck = await _databaseService.getLastSyncTime();
    if (!force &&
        lastCheck != null &&
        frequency.interval != Duration.zero &&
        now.difference(lastCheck) < frequency.interval) {
      LoggerService.info(
        'Sync skipped: next check scheduled for '
        '${lastCheck.add(frequency.interval).toIso8601String()}',
      );
      return false;
    }

    return _performSync(reportStatus);
  }

  /// Parses the remote download page to infer last update dates for each source.
  /// Strategy: specific file dates -> global date banner -> null (forces hash check).
  /// Exposed for testing to validate scraping logic against the live BDPM website.
  @visibleForTesting
  Future<Map<String, DateTime>> fetchRemoteDates() async {
    try {
      final response = await _dio.get<String>(
        _updatePageUrl,
        options: Options(responseType: ResponseType.plain),
      );
      if (response.statusCode != 200 || response.data == null) {
        return {};
      }
      final html = response.data!;
      final remoteDates = <String, DateTime>{};

      DateTime? globalDate;
      final globalRegex = RegExp(
        r'Dernière mise à jour le\s*(\d{2}/\d{2}/\d{4})',
        caseSensitive: false,
      );
      final globalMatch = globalRegex.firstMatch(html);
      if (globalMatch != null) {
        globalDate = _parseFrenchDate(globalMatch.group(1)!);
        if (globalDate != null) {
          LoggerService.info('Global page update date found: $globalDate');
        }
      }

      final regex = RegExp(
        r'href="/download/file/([^"]+)".*?Date de mise à jour\s*:\s*(\d{2}/\d{2}/\d{4})',
        caseSensitive: false,
        dotAll: true,
      );

      final matches = regex.allMatches(html);
      for (final match in matches) {
        final filename = match.group(1);
        final dateString = match.group(2);
        if (filename == null || dateString == null) continue;

        final sourceKey = DataSources.files.entries
            .firstWhereOrNull((entry) => entry.value.endsWith(filename))
            ?.key;
        if (sourceKey == null) continue;

        final date = _parseFrenchDate(dateString);
        if (date != null) {
          remoteDates[sourceKey] = date;
        }
      }

      if (globalDate != null) {
        for (final key in DataSources.files.keys) {
          remoteDates.putIfAbsent(key, () => globalDate!);
        }
      }

      return remoteDates;
    } catch (error, stackTrace) {
      LoggerService.error('Failed to parse update page', error, stackTrace);
      return {};
    }
  }

  DateTime? _parseFrenchDate(String dateStr) {
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _performSync(SyncStatusReporter reportStatus) async {
    _isRunning = true;
    final downloadedFiles = <String, File>{};
    final datesToUpdate = <String, DateTime>{};
    final sourceHashes = await _databaseService.getSourceHashes();
    final sourceDates = await _databaseService.getSourceDates();
    var hasChanges = false;
    var currentStep = 'initialisation';
    try {
      LoggerService.info('Starting sync run');
      reportStatus(
        const SyncProgress(
          phase: SyncPhase.waitingNetwork,
          code: SyncStatusCode.waitingNetwork,
        ),
      );
      currentStep = 'wait_connectivity';
      await _waitForConnectivity();

      reportStatus(
        const SyncProgress(
          phase: SyncPhase.checking,
          code: SyncStatusCode.checkingUpdates,
        ),
      );
      currentStep = 'fetch_remote_dates';

      final remoteDates = await fetchRemoteDates();
      final sourcesToDownload = <MapEntry<String, String>>[];
      final allSources = DataSources.files.entries.toList();

      if (remoteDates.isEmpty) {
        LoggerService.warning(
          'Date parsing failed. Falling back to Hash Check.',
        );
        sourcesToDownload.addAll(allSources);
      } else {
        for (final entry in allSources) {
          final key = entry.key;
          final remoteDate = remoteDates[key];
          final localDate = sourceDates[key];

          if (remoteDate == null) {
            sourcesToDownload.add(entry);
            continue;
          }

          if (localDate == null || remoteDate.isAfter(localDate)) {
            sourcesToDownload.add(entry);
            datesToUpdate[key] = remoteDate;
            LoggerService.info(
              'Update found for $key: $localDate -> $remoteDate',
            );
          }
        }
      }

      if (sourcesToDownload.isEmpty) {
        LoggerService.info(
          'No updates required. Remote dates match local cache.',
        );
        reportStatus(
          const SyncProgress(
            phase: SyncPhase.success,
            code: SyncStatusCode.successAlreadyCurrent,
          ),
        );
        return false;
      }

      for (var i = 0; i < sourcesToDownload.length; i++) {
        final entry = sourcesToDownload[i];
        currentStep = 'download_${entry.key}';
        LoggerService.info('Downloading ${entry.key} from ${entry.value}');
        reportStatus(
          SyncProgress(
            phase: SyncPhase.downloading,
            code: SyncStatusCode.downloadingSource,
            subject: entry.key,
            progress: (i + 1) / sourcesToDownload.length,
          ),
        );

        final tempFile = await _downloadFile(entry.value, entry.key);
        final hash = await _computeSha256(tempFile);
        final previousHash = sourceHashes[entry.key];

        if (previousHash != hash) {
          hasChanges = true;
          sourceHashes[entry.key] = hash;
        }

        final pendingDate = datesToUpdate[entry.key];
        if (pendingDate != null) {
          sourceDates[entry.key] = pendingDate;
        }

        downloadedFiles[entry.key] = tempFile;
      }

      await _databaseService.saveSourceHashes(sourceHashes);
      await _databaseService.saveSourceDates(sourceDates);

      if (hasChanges) {
        currentStep = 'apply_update';
        LoggerService.info(
          'Applying BDPM update (files changed: ${downloadedFiles.keys.join(', ')})',
        );
        reportStatus(
          const SyncProgress(
            phase: SyncPhase.applying,
            code: SyncStatusCode.applyingUpdate,
          ),
        );
        await _dataInitializationService.applyUpdate(downloadedFiles);
      }

      reportStatus(
        SyncProgress(
          phase: SyncPhase.success,
          code: hasChanges
              ? SyncStatusCode.successUpdatesApplied
              : SyncStatusCode.successVerified,
        ),
      );
      LoggerService.info('Sync completed. Changes applied: $hasChanges');

      return hasChanges;
    } catch (error, stackTrace) {
      reportStatus(
        SyncProgress(
          phase: SyncPhase.error,
          code: SyncStatusCode.error,
          subject: currentStep,
          errorType: _mapErrorTypeForStep(currentStep),
        ),
      );
      LoggerService.error(
        'Sync failed at step "$currentStep"',
        error,
        stackTrace,
      );
      rethrow;
    } finally {
      for (final file in downloadedFiles.values) {
        await _safeDelete(file);
      }
      await _databaseService.updateSyncTimestamp(
        _clock().millisecondsSinceEpoch,
      );
      _scheduleReset(reportStatus);
      _isRunning = false;
    }
  }

  Future<void> _scheduleReset(SyncStatusReporter reportStatus) async {
    await Future<void>.delayed(const Duration(seconds: 3));
    reportStatus(
      const SyncProgress(phase: SyncPhase.idle, code: SyncStatusCode.idle),
    );
  }

  SyncErrorType _mapErrorTypeForStep(String step) {
    if (step.startsWith('download_')) {
      return SyncErrorType.download;
    }
    switch (step) {
      case 'wait_connectivity':
        return SyncErrorType.network;
      case 'fetch_remote_dates':
        return SyncErrorType.scraping;
      case 'apply_update':
        return SyncErrorType.apply;
      default:
        return SyncErrorType.unknown;
    }
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
    // WHY: Use centralized FileDownloader service for consistent error handling,
    // timeouts, and Talker logging across all file downloads.
    return _fileDownloadService.downloadToTempFile(
      url: url,
      tempPathPrefix: '${Directory.systemTemp.path}/pharma_sync_${key}_',
    );
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
}
