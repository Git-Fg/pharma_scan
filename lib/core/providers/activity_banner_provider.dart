import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pharma_scan/core/domain/models/sync_state.dart';
import 'package:pharma_scan/core/services/data_initialization_models.dart';
import 'package:pharma_scan/core/providers/initialization_provider.dart';
import 'package:pharma_scan/core/providers/sync_provider.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/unified_activity_banner.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

part 'activity_banner_provider.g.dart';

/// Provider that maps sync and initialization state to activity banner properties.
@riverpod
ActivityBannerState? activityBanner(Ref ref) {
  final syncProgress = ref.watch(syncControllerProvider);
  final initState = ref.watch(initializationStateProvider);
  final initStepAsync = ref.watch(initializationStepProvider);
  final initStep = initStepAsync.maybeWhen(
    data: (value) => value,
    orElse: () => null,
  );
  final initDetailAsync = ref.watch(initializationDetailProvider);
  final initDetail = initDetailAsync.maybeWhen(
    data: (value) => value,
    orElse: () => null,
  );
  final initializationErrorMessage = ref.watch(
    initializationErrorMessageProvider,
  );

  final isInitializationErrored = initState == .error;
  final isInitializationActive =
      initState == .initializing ||
      (initStep != null &&
          initStep != .idle &&
          initStep != .ready &&
          initStep != .error);

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
      onRetry: () => ref.read(initializationProvider.notifier).retry(),
    );
  }

  // Priority 2: Initialization Active
  if (isInitializationActive) {
    const List<InitializationStep> stages = [.downloading];
    final currentStage = initStep ?? .downloading;
    double? initProgress;
    final stageIndex = stages.indexOf(currentStage);
    if (stageIndex >= 0) {
      initProgress = (stageIndex + 1) / stages.length;
    } else if (currentStage == .ready) {
      initProgress = 1;
    }
    final (status, description, icon) = switch (currentStage) {
      .downloading => (
        Strings.initializationDownloading,
        Strings.initializationDownloadingDescription,
        LucideIcons.download,
      ),
      .ready => (
        Strings.initializationReady,
        Strings.initializationReady,
        LucideIcons.check,
      ),
      .error => (
        Strings.initializationError,
        Strings.initializationError,
        LucideIcons.triangleAlert,
      ),
      .updateAvailable => (
        'Mise à jour disponible',
        'Une nouvelle version de la base de données est disponible.',
        LucideIcons.refreshCw,
      ),
      .idle => ('', '', LucideIcons.circleDot),
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
  if (syncProgress.phase != .idle) {
    final presenter = SyncStatusPresenter(syncProgress);
    IconData icon = LucideIcons.circleDashed;
    String status = '';
    String? description;
    var indeterminate = true;
    double? progressValue;
    var isError = false;

    switch (syncProgress.phase) {
      case .waitingNetwork:
        icon = LucideIcons.wifiOff;
        status = Strings.dataOperationsWaitingNetwork;
        description = Strings.syncWaitingNetwork;
      case .waitingUser:
        icon = LucideIcons.info;
        status = 'Mise à jour disponible';
        description = 'En attente de confirmation...';
      case .checking:
        icon = LucideIcons.search;
        status = Strings.dataOperationsCheckingUpdates;
        description = Strings.syncCheckingUpdates;
      case .downloading:
        icon = LucideIcons.download;
        status = Strings.syncBannerDownloadingTitle;
        description = Strings.syncDownloadingSource(
          syncProgress.subject ?? Strings.data,
        );
        indeterminate = false;
        progressValue = syncProgress.progress;
      case .applying:
        icon = LucideIcons.databaseZap;
        status = Strings.syncBannerApplyingTitle;
        description = Strings.syncApplyingUpdate;
      case .success:
        icon = LucideIcons.circleCheck;
        status = Strings.syncBannerSuccessTitle;
        description =
            presenter.successDescription ?? Strings.syncDatabaseUpdated;
        indeterminate = false;
        progressValue = 1;
      case .error:
        icon = LucideIcons.triangleAlert;
        status = Strings.syncBannerErrorTitle;
        description = presenter.errorDescription ?? Strings.syncFailedMessage;
        isError = true;
      case .idle:
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

  return null;
}

/// Helper class to extract status messages from SyncProgress.
class SyncStatusPresenter {
  const SyncStatusPresenter(this.progress);

  final SyncProgress progress;

  String? get successDescription {
    return switch (progress.code) {
      .successAlreadyCurrent => Strings.syncUpToDate,
      .successUpdatesApplied => Strings.syncDatabaseUpdated,
      .successVerified => Strings.syncContentVerified,
      .idle ||
      .waitingNetwork ||
      .checkingUpdates ||
      .downloadingSource ||
      .applyingUpdate ||
      .error => null,
    };
  }

  String? get errorDescription {
    switch (progress.errorType) {
      case .network:
        return Strings.syncErrorNetwork;
      case .scraping:
        return Strings.syncErrorScraping;
      case .download:
        return Strings.syncErrorDownload;
      case .apply:
        return Strings.syncErrorApply;
      case .unknown:
      case null:
        return Strings.syncErrorUnknown;
    }
  }
}
