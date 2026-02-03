@Tags(['providers'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/domain/models/sync_state.dart';
import 'package:pharma_scan/core/widgets/unified_activity_banner.dart';

void main() {
  group('ActivityBannerState', () {
    test('has correct default values', () {
      final state = ActivityBannerState(
        icon: Icons.info,
        title: 'Test',
        status: 'Status',
      );

      expect(state.icon, Icons.info);
      expect(state.title, 'Test');
      expect(state.status, 'Status');
      expect(state.secondaryStatus, isNull);
      expect(state.progressValue, isNull);
      expect(state.progressLabel, isNull);
      expect(state.indeterminate, false);
      expect(state.isError, false);
      expect(state.onRetry, isNull);
    });

    test('can be created with all parameters', () {
      void onRetry() {}
      final state = ActivityBannerState(
        icon: Icons.error,
        title: 'Error',
        status: 'Something went wrong',
        secondaryStatus: 'Details',
        progressValue: 0.5,
        progressLabel: '50%',
        indeterminate: false,
        isError: true,
        onRetry: onRetry,
      );

      expect(state.isError, true);
      expect(state.onRetry, onRetry);
      expect(state.progressValue, 0.5);
    });
  });

  group('SyncProgress', () {
    test('idle has correct default values', () {
      final progress = SyncProgress.idle;

      expect(progress.phase, SyncPhase.idle);
      expect(progress.code, SyncStatusCode.idle);
      expect(progress.progress, isNull);
      expect(progress.subject, isNull);
    });

    test('can be created with custom values', () {
      final progress = SyncProgress(
        phase: SyncPhase.downloading,
        code: SyncStatusCode.downloadingSource,
        subject: 'database',
        progress: 0.75,
      );

      expect(progress.phase, SyncPhase.downloading);
      expect(progress.code, SyncStatusCode.downloadingSource);
      expect(progress.subject, 'database');
      expect(progress.progress, 0.75);
    });

    test('elapsed returns null when startTime is null', () {
      final progress = SyncProgress(
        phase: SyncPhase.idle,
        code: SyncStatusCode.idle,
      );

      expect(progress.elapsed, isNull);
    });

    test('SyncPhase enum has expected values', () {
      expect(SyncPhase.values, contains(SyncPhase.idle));
      expect(SyncPhase.values, contains(SyncPhase.waitingNetwork));
      expect(SyncPhase.values, contains(SyncPhase.checking));
      expect(SyncPhase.values, contains(SyncPhase.downloading));
      expect(SyncPhase.values, contains(SyncPhase.success));
      expect(SyncPhase.values, contains(SyncPhase.error));
    });

    test('SyncStatusCode enum has expected values', () {
      expect(SyncStatusCode.values, contains(SyncStatusCode.idle));
      expect(SyncStatusCode.values, contains(SyncStatusCode.successAlreadyCurrent));
      expect(SyncStatusCode.values, contains(SyncStatusCode.successUpdatesApplied));
      expect(SyncStatusCode.values, contains(SyncStatusCode.downloadingSource));
    });

    test('SyncErrorType enum has expected values', () {
      expect(SyncErrorType.values, contains(SyncErrorType.network));
      expect(SyncErrorType.values, contains(SyncErrorType.download));
      expect(SyncErrorType.values, contains(SyncErrorType.unknown));
    });

    test('SyncProgress phases have distinct values', () {
      final phases = SyncPhase.values;
      expect(phases.toSet().length, equals(phases.length));
    });

    test('SyncStatusCode values are unique', () {
      final codes = SyncStatusCode.values;
      expect(codes.toSet().length, equals(codes.length));
    });
  });
}
