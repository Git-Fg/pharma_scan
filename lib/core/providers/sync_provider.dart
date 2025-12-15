import 'dart:async';

import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/providers/capability_providers.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/domain/models/sync_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pharma_scan/core/utils/async_utils.dart';

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
      ref.read(loggerProvider).info('Sync already in progress. Skipping.');
      return false;
    }

    final frequencyRaw = ref.read(updateFrequencyProvider);
    final frequency = UpdateFrequency.values.firstWhere(
      (f) => f.name == frequencyRaw,
      orElse: () => UpdateFrequency.daily,
    );
    if (!force && frequency == UpdateFrequency.none) {
      ref
          .read(loggerProvider)
          .info('Sync skipped: disabled by user preference');
      return false;
    }

    final clock = ref.read(clockProvider);
    final now = clock();
    final appSettings = ref.read(appSettingsDaoProvider);
    final lastCheck = await appSettings.lastSyncTime;
    if (!ref.mounted) return false;

    if (!force &&
        lastCheck != null &&
        frequency.interval != Duration.zero &&
        now.difference(lastCheck) < frequency.interval) {
      ref.read(loggerProvider).info(
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
      ref
          .read(loggerProvider)
          .info('Starting database update from GitHub Releases');

      // Use DataInitializationService to handle database updates
      final dataInitService = ref.read(dataInitializationServiceProvider);

      state = SyncProgress(
        phase: SyncPhase.downloading,
        code: SyncStatusCode.checkingUpdates,
        startTime: syncStartTime,
      );

      final updated = await dataInitService.updateDatabase();

      if (updated) {
        state = SyncProgress(
          phase: SyncPhase.success,
          code: SyncStatusCode.successUpdatesApplied,
          startTime: syncStartTime,
        );
        ref.read(loggerProvider).info('Database update completed successfully');
        return true;
      } else {
        state = SyncProgress(
          phase: SyncPhase.success,
          code: SyncStatusCode.successAlreadyCurrent,
          startTime: syncStartTime,
        );
        ref.read(loggerProvider).info('Database is already up to date');
        return false;
      }
    } on Exception catch (error, stackTrace) {
      state = SyncProgress(
        phase: SyncPhase.error,
        code: SyncStatusCode.error,
        errorType: SyncErrorType.download,
        startTime: syncStartTime,
      );

      ref
          .read(loggerProvider)
          .error('Database update failed', error, stackTrace);
      return false;
    } finally {
      if (ref.mounted) {
        final clock = ref.read(clockProvider);
        final appSettings = ref.read(appSettingsDaoProvider);
        try {
          await appSettings.setLastSyncTime(clock());
        } on Exception catch (e, s) {
          ref.read(loggerProvider).error(
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
