import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/config/data_sources.dart';
import 'package:pharma_scan/core/errors/failures.dart';
import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/providers/capability_providers.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/features/home/models/sync_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_provider.g.dart';

enum _SyncStep {
  initialization,
  waitConnectivity,
  fetchRemoteDates,
  downloadFile,
  applyUpdate,
}

@Riverpod(keepAlive: true)
class SyncController extends _$SyncController {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: const {'Accept': 'text/html,*/*'},
    ),
  );

  @override
  SyncProgress build() {
    return SyncProgress.idle;
  }

  /// Triggers the synchronization process.
  /// Returns `true` if updates were applied, `false` otherwise.
  Future<bool> startSync({bool force = false}) async {
    if (state.phase != SyncPhase.idle &&
        state.phase != SyncPhase.error &&
        state.phase != SyncPhase.success) {
      LoggerService.info('Sync already in progress. Skipping.');
      return false;
    }

    final frequencyAsync = ref.read(appPreferencesProvider);
    final frequency = frequencyAsync.maybeWhen(
      data: (freq) => freq,
      orElse: () => UpdateFrequency.daily,
    );
    if (!force && frequency == UpdateFrequency.none) {
      LoggerService.info('Sync skipped: disabled by user preference');
      return false;
    }

    final clock = ref.read(clockProvider);
    final now = clock();
    final db = ref.read(appDatabaseProvider);
    final lastCheck = await db.settingsDao.getLastSyncTime();
    if (!ref.mounted) return false;

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

    return _performSync();
  }

  Future<bool> _performSync() async {
    final syncStartTime = DateTime.now();
    SyncProgress buildState({
      required SyncPhase phase,
      required SyncStatusCode code,
      double? progress,
      String? subject,
      SyncErrorType? errorType,
      int? totalBytes,
      int? receivedBytes,
    }) {
      return SyncProgress(
        phase: phase,
        code: code,
        progress: progress,
        subject: subject,
        errorType: errorType,
        startTime: syncStartTime,
        totalBytes: totalBytes,
        receivedBytes: receivedBytes,
      );
    }

    state = buildState(
      phase: SyncPhase.waitingNetwork,
      code: SyncStatusCode.waitingNetwork,
    );

    final downloadedFiles = <String, File>{};
    final datesToUpdate = <String, DateTime>{};
    var hasChanges = false;
    var currentStep = _SyncStep.initialization;
    String? currentSubject;

    try {
      LoggerService.info('Starting sync run (Notifier)');
      final db = ref.read(appDatabaseProvider);
      final sourceHashes = await db.settingsDao.getSourceHashes();
      final sourceDates = await db.settingsDao.getSourceDates();

      currentStep = _SyncStep.waitConnectivity;
      await _waitForConnectivity();
      if (!ref.mounted) return false;

      state = buildState(
        phase: SyncPhase.checking,
        code: SyncStatusCode.checkingUpdates,
      );
      currentStep = _SyncStep.fetchRemoteDates;

      final remoteDates = await fetchRemoteDates();
      if (!ref.mounted) return false;
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
        state = buildState(
          phase: SyncPhase.success,
          code: SyncStatusCode.successAlreadyCurrent,
        );
        return false;
      }

      for (var i = 0; i < sourcesToDownload.length; i++) {
        final entry = sourcesToDownload[i];
        currentStep = _SyncStep.downloadFile;
        currentSubject = entry.key;
        LoggerService.info('Downloading ${entry.key} from ${entry.value}');

        state = buildState(
          phase: SyncPhase.downloading,
          code: SyncStatusCode.downloadingSource,
          subject: entry.key,
          progress: 0,
        );

        final tempFile = await _downloadFile(
          entry.value,
          entry.key,
          onProgress: (received, total) {
            if (total <= 0) return;
            if (!ref.mounted) return;
            state = state.copyWith(
              progress: total > 0 ? received / total : state.progress,
              subject: entry.key,
              totalBytes: total,
              receivedBytes: received,
            );
          },
        );
        if (!ref.mounted) return false;
        final hash = await _computeSha256(tempFile);
        if (!ref.mounted) return false;
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

      try {
        await db.settingsDao.saveSourceHashes(
          sourceHashes,
        );
        if (!ref.mounted) return hasChanges;
      } on Exception catch (e, s) {
        LoggerService.error(
          '[SyncController] Failed to save source hashes',
          e,
          s,
        );
      }
      try {
        await db.settingsDao.saveSourceDates(
          sourceDates,
        );
        if (!ref.mounted) return hasChanges;
      } on Exception catch (e, s) {
        LoggerService.error(
          '[SyncController] Failed to save source dates',
          e,
          s,
        );
      }

      if (hasChanges) {
        currentStep = _SyncStep.applyUpdate;
        currentSubject = null;
        LoggerService.info(
          'Applying BDPM update (files changed: ${downloadedFiles.keys.join(', ')})',
        );
        state = buildState(
          phase: SyncPhase.applying,
          code: SyncStatusCode.applyingUpdate,
        );

        final dataInit = ref.read(dataInitializationServiceProvider);
        await dataInit.applyUpdate(downloadedFiles);
        if (!ref.mounted) return false;
      }

      state = buildState(
        phase: SyncPhase.success,
        code: hasChanges
            ? SyncStatusCode.successUpdatesApplied
            : SyncStatusCode.successVerified,
      );
      LoggerService.info('Sync completed. Changes applied: $hasChanges');

      return hasChanges;
    } on Failure catch (error, stackTrace) {
      final errorSubject = currentSubject != null
          ? 'download_$currentSubject'
          : currentStep.name;

      state = buildState(
        phase: SyncPhase.error,
        code: SyncStatusCode.error,
        subject: errorSubject,
        errorType: _mapErrorTypeForStep(currentStep),
      );

      LoggerService.error(
        'Sync failed at step "${currentStep.name}"${currentSubject != null ? ' ($currentSubject)' : ''}',
        error,
        stackTrace,
      );

      // Swallow the error after updating state and logging so callers receive
      // a non-throwing result while UI can react to the error state.
      return false;
    } on Object catch (error, stackTrace) {
      final errorSubject = currentSubject != null
          ? 'download_$currentSubject'
          : currentStep.name;

      state = buildState(
        phase: SyncPhase.error,
        code: SyncStatusCode.error,
        subject: errorSubject,
        errorType: _mapErrorTypeForStep(currentStep),
      );

      LoggerService.error(
        'Sync failed with unexpected error at step "${currentStep.name}"${currentSubject != null ? ' ($currentSubject)' : ''}',
        error,
        stackTrace,
      );

      rethrow;
    } finally {
      for (final file in downloadedFiles.values) {
        await _safeDelete(file);
      }
      if (ref.mounted) {
        final clock = ref.read(clockProvider);
        final db = ref.read(appDatabaseProvider);
        try {
          await db.settingsDao.updateSyncTimestamp(
            clock().millisecondsSinceEpoch,
          );
        } on Exception catch (e, s) {
          LoggerService.error(
            '[SyncController] Failed to update sync timestamp',
            e,
            s,
          );
        }
        unawaited(_scheduleReset());
      }
    }
  }

  Future<void> _scheduleReset() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!ref.mounted) return;
    if (state.phase != SyncPhase.checking &&
        state.phase != SyncPhase.downloading &&
        state.phase != SyncPhase.applying) {
      state = SyncProgress.idle;
    }
  }

  @visibleForTesting
  Future<Map<String, DateTime>> fetchRemoteDates() async {
    try {
      final response = await _dio.get<String>(
        DataSources.updatePageUrl,
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
    } on Exception catch (error, stackTrace) {
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
    } on Exception catch (_) {
      return null;
    }
  }

  Future<void> _waitForConnectivity() async {
    final check = ref.read(connectivityCheckProvider);
    while (true) {
      if (!ref.mounted) return;
      final hasConnectivity = await check();
      if (!ref.mounted) return;
      if (hasConnectivity) return;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  Future<File> _downloadFile(
    String url,
    String key, {
    void Function(int received, int total)? onProgress,
  }) async {
    final downloader = ref.read(fileDownloadServiceProvider);
    final downloadEither = await downloader.downloadToTempFile(
      url: url,
      tempPathPrefix: '${Directory.systemTemp.path}/pharma_sync_${key}_',
      onReceiveProgress: onProgress,
    );
    return downloadEither.fold(
      ifLeft: (failure) => throw failure,
      ifRight: (file) => file,
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
    } on Exception catch (_) {
      // Ignore failures
    }
  }

  SyncErrorType _mapErrorTypeForStep(_SyncStep step) {
    switch (step) {
      case _SyncStep.downloadFile:
        return SyncErrorType.download;
      case _SyncStep.waitConnectivity:
        return SyncErrorType.network;
      case _SyncStep.fetchRemoteDates:
        return SyncErrorType.scraping;
      case _SyncStep.applyUpdate:
        return SyncErrorType.apply;
      case _SyncStep.initialization:
        return SyncErrorType.unknown;
    }
  }
}
