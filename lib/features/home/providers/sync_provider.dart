import 'dart:async';

import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/providers/capability_providers.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:pharma_scan/features/home/models/sync_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_provider.g.dart';

@Riverpod(keepAlive: true)
class SyncController extends _$SyncController {
  @override
  SyncProgress build() {
    return SyncProgress.idle;
  }

  /// Triggers the database synchronization from GitHub Releases.
  /// Returns `true` if updates were applied, `false` otherwise.
  Future<bool> startSync({bool force = false}) async {
    if (state.phase != SyncPhase.idle &&
        state.phase != SyncPhase.error &&
        state.phase != SyncPhase.success) {
      LoggerService.info('Sync already in progress. Skipping.');
      return false;
    }

    final frequency = ref.read(appPreferencesProvider);
    if (!force && frequency == UpdateFrequency.none) {
      LoggerService.info('Sync skipped: disabled by user preference');
      return false;
    }

    final clock = ref.read(clockProvider);
    final now = clock();
    final prefs = ref.read(preferencesServiceProvider);
    final lastCheck = prefs.getLastSyncTime();
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

    return _performDatabaseUpdate();
  }

  Future<bool> _performDatabaseUpdate() async {
    final syncStartTime = DateTime.now();

    state = SyncProgress(
      phase: SyncPhase.checking,
      code: SyncStatusCode.checkingUpdates,
      startTime: syncStartTime,
    );

    try {
      LoggerService.info('Starting database update from GitHub Releases');

      // Use DataInitializationService to handle database updates
      final dataInitService = ref.read(dataInitializationServiceProvider);

      state = SyncProgress(
        phase: SyncPhase.downloading,
        code: SyncStatusCode.checkingUpdates,
        startTime: syncStartTime,
      );

      final updated = await dataInitService.updateDatabase(force: false);

      if (updated) {
        state = SyncProgress(
          phase: SyncPhase.success,
          code: SyncStatusCode.successUpdatesApplied,
          startTime: syncStartTime,
        );
        LoggerService.info('Database update completed successfully');
        return true;
      } else {
        state = SyncProgress(
          phase: SyncPhase.success,
          code: SyncStatusCode.successAlreadyCurrent,
          startTime: syncStartTime,
        );
        LoggerService.info('Database is already up to date');
        return false;
      }
    } on Exception catch (error, stackTrace) {
      state = SyncProgress(
        phase: SyncPhase.error,
        code: SyncStatusCode.error,
        errorType: SyncErrorType.download,
        startTime: syncStartTime,
      );

      LoggerService.error('Database update failed', error, stackTrace);
      return false;
    } finally {
      if (ref.mounted) {
        final clock = ref.read(clockProvider);
        final prefsService = ref.read(preferencesServiceProvider);
        try {
          await prefsService.setLastSyncTime(
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
}