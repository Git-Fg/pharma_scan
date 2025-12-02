import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/home/models/sync_state.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:pharma_scan/features/home/providers/sync_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

part 'activity_banner_viewmodel.g.dart';

/// Data class holding all properties needed to render UnifiedActivityBanner.
class ActivityBannerState {
  const ActivityBannerState({
    required this.icon,
    required this.title,
    required this.status,
    this.secondaryStatus,
    this.progressValue,
    this.progressLabel,
    this.indeterminate = false,
    this.isError = false,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String status;
  final String? secondaryStatus;
  final double? progressValue;
  final String? progressLabel;
  final bool indeterminate;
  final bool isError;
  final VoidCallback? onRetry;
}

/// Provider that maps sync and initialization state to activity banner properties.
@riverpod
ActivityBannerState? activityBannerViewModel(Ref ref) {
  final syncProgress = ref.watch(syncControllerProvider);
  final initState = ref.watch(initializationStateProvider);
  final initStepAsync = ref.watch(
    initializationStepProvider,
  );
  final initStep = initStepAsync.maybeWhen(
    data: (value) => value,
    orElse: () => null,
  );
  final initDetailAsync = ref.watch(
    initializationDetailProvider,
  );
  final initDetail = initDetailAsync.maybeWhen(
    data: (value) => value,
    orElse: () => null,
  );
  final initializationErrorMessage = ref.watch(
    initializationErrorMessageProvider,
  );

  final isInitializationErrored = initState == InitializationState.error;
  final isInitializationActive =
      initState == InitializationState.initializing ||
      (initStep != null &&
          initStep != InitializationStep.idle &&
          initStep != InitializationStep.ready &&
          initStep != InitializationStep.error);

  // Priority 1: Initialization Error
  if (isInitializationErrored) {
    return ActivityBannerState(
      icon: LucideIcons.triangleAlert,
      title: Strings.dataOperationsTitle,
      status: Strings.initializationError,
      secondaryStatus:
          initializationErrorMessage ?? Strings.initializationErrorDescription,
      indeterminate: true,
      isError: true,
      onRetry: () =>
          ref.read(initializationStateProvider.notifier).initialize(),
    );
  }

  // Priority 2: Initialization Active
  if (isInitializationActive) {
    const stages = [
      InitializationStep.downloading,
      InitializationStep.parsing,
      InitializationStep.aggregating,
    ];
    final currentStage = initStep ?? InitializationStep.downloading;
    double? initProgress;
    final stageIndex = stages.indexOf(currentStage);
    if (stageIndex >= 0) {
      initProgress = (stageIndex + 1) / stages.length;
    } else if (currentStage == InitializationStep.ready) {
      initProgress = 1;
    }
    final (status, description, icon) = switch (currentStage) {
      InitializationStep.downloading => (
        Strings.initializationDownloading,
        Strings.initializationDownloadingDescription,
        LucideIcons.download,
      ),
      InitializationStep.parsing => (
        Strings.initializationParsing,
        Strings.initializationParsingDescription,
        LucideIcons.fileDigit,
      ),
      InitializationStep.aggregating => (
        Strings.initializationAggregatingTitle,
        Strings.initializationAggregatingDescription,
        LucideIcons.database,
      ),
      _ => (
        Strings.initializationInProgress,
        Strings.initializationDescription,
        LucideIcons.loader,
      ),
    };
    return ActivityBannerState(
      icon: icon,
      title: Strings.dataOperationsTitle,
      status: status,
      secondaryStatus: initDetail ?? description,
      progressValue: initProgress,
      progressLabel: initProgress != null
          ? Strings.dataOperationsProgressLabel(initProgress * 100, status)
          : null,
      indeterminate: initProgress == null,
    );
  }

  // Priority 3: Sync Progress
  if (syncProgress.phase != SyncPhase.idle) {
    final presenter = SyncStatusPresenter(syncProgress);
    IconData icon;
    String status;
    String? description;
    var indeterminate = true;
    double? progressValue;
    var isError = false;

    switch (syncProgress.phase) {
      case SyncPhase.waitingNetwork:
        icon = LucideIcons.wifiOff;
        status = Strings.dataOperationsWaitingNetwork;
        description = Strings.syncWaitingNetwork;
      case SyncPhase.checking:
        icon = LucideIcons.search;
        status = Strings.dataOperationsCheckingUpdates;
        description = Strings.syncCheckingUpdates;
      case SyncPhase.downloading:
        icon = LucideIcons.download;
        status = Strings.syncBannerDownloadingTitle;
        description = Strings.syncDownloadingSource(
          syncProgress.subject ?? Strings.data,
        );
        indeterminate = false;
        progressValue = syncProgress.progress;
      case SyncPhase.applying:
        icon = LucideIcons.databaseZap;
        status = Strings.syncBannerApplyingTitle;
        description = Strings.syncApplyingUpdate;
      case SyncPhase.success:
        icon = LucideIcons.circleCheck;
        status = Strings.syncBannerSuccessTitle;
        description =
            presenter.successDescription ?? Strings.syncDatabaseUpdated;
        indeterminate = false;
        progressValue = 1;
      case SyncPhase.error:
        icon = LucideIcons.triangleAlert;
        status = Strings.syncBannerErrorTitle;
        description = presenter.errorDescription ?? Strings.syncFailedMessage;
        isError = true;
      case SyncPhase.idle:
        icon = LucideIcons.loader;
        status = Strings.dataOperationsIdle;
    }

    return ActivityBannerState(
      icon: icon,
      title: Strings.dataOperationsTitle,
      status: status,
      secondaryStatus: description,
      progressValue: progressValue,
      progressLabel: progressValue != null
          ? Strings.dataOperationsProgressLabel(progressValue * 100, status)
          : null,
      indeterminate: indeterminate,
      isError: isError,
      onRetry: isError
          ? () => unawaited(
              ref.read(syncControllerProvider.notifier).startSync(force: true),
            )
          : null,
    );
  }

  // No banner to show
  return null;
}

/// Helper class to extract status messages from SyncProgress.
class SyncStatusPresenter {
  const SyncStatusPresenter(this.progress);

  final SyncProgress progress;

  String? get successDescription {
    return switch (progress.code) {
      SyncStatusCode.successAlreadyCurrent => Strings.syncUpToDate,
      SyncStatusCode.successUpdatesApplied => Strings.syncDatabaseUpdated,
      SyncStatusCode.successVerified => Strings.syncContentVerified,
      SyncStatusCode.idle ||
      SyncStatusCode.waitingNetwork ||
      SyncStatusCode.checkingUpdates ||
      SyncStatusCode.downloadingSource ||
      SyncStatusCode.applyingUpdate ||
      SyncStatusCode.error => null,
    };
  }

  String? get errorDescription {
    switch (progress.errorType) {
      case SyncErrorType.network:
        return Strings.syncErrorNetwork;
      case SyncErrorType.scraping:
        return Strings.syncErrorScraping;
      case SyncErrorType.download:
        return Strings.syncErrorDownload;
      case SyncErrorType.apply:
        return Strings.syncErrorApply;
      case SyncErrorType.unknown:
      case null:
        return Strings.syncErrorUnknown;
    }
  }
}
