// lib/features/home/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:forui/forui.dart';

import 'package:pharma_scan/core/router/routes.dart';
import 'package:pharma_scan/core/utils/app_animations.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/testable.dart';
import 'package:pharma_scan/features/home/providers/sync_provider.dart';
import 'package:pharma_scan/features/home/models/sync_state.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/features/home/widgets/unified_activity_banner.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MainScreen extends HookConsumerWidget {
  const MainScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // WHY: Trigger sync after first frame
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(syncControllerProvider.notifier)
            .startSync(force: false)
            .catchError((_) => false);
      });
      return null;
    }, []);

    void onTabChanged(int index) {
      // "goBranch" switches the tab.
      // "initialLocation: index == navigationShell.currentIndex" implements the
      // standard behavior: if you tap the active tab, it pops to the root of that tab.
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    Future<bool> triggerSync({bool force = false}) {
      return ref
          .read(syncControllerProvider.notifier)
          .startSync(force: force)
          .catchError((_) => false);
    }

    final titles = [Strings.scanner, Strings.explorer];
    final syncProgress = ref.watch(syncControllerProvider);
    final initState = ref.watch(initializationStateProvider);
    final initStepAsync = ref.watch(initializationStepProvider);
    final initStep = initStepAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final initializationErrorMessage = ref.watch(
      initializationErrorMessageProvider,
    );
    final initTimerStart = useState<DateTime?>(null);

    // WHY: Listen for sync status changes to show toast notifications
    // Data providers are now reactive to sync completion via lastSyncEpochStreamProvider
    ref.listen(syncControllerProvider, (previous, next) {
      final presenter = SyncStatusPresenter(next);
      if (next.phase == SyncPhase.success &&
          previous?.phase != SyncPhase.success) {
        // Show success toast notification
        if (context.mounted) {
          showFToast(
            context: context,
            title: const Text(Strings.updateCompleted),
            description: Text(
              presenter.successDescription ?? Strings.bdpmUpToDate,
            ),
            icon: const Icon(FIcons.check),
          );
        }
      } else if (next.phase == SyncPhase.error &&
          previous?.phase != SyncPhase.error) {
        // Show error toast notification only on transition to error
        if (context.mounted) {
          showFToast(
            context: context,
            title: const Text(Strings.syncFailed),
            description: Text(
              presenter.errorDescription ?? Strings.syncFailedMessage,
            ),
            icon: const Icon(FIcons.triangleAlert),
          );
        }
      }
    });

    final isInitializationErrored = initState == InitializationState.error;
    final isInitializationActive =
        initState == InitializationState.initializing ||
        (initStep != null &&
            initStep != InitializationStep.idle &&
            initStep != InitializationStep.ready &&
            initStep != InitializationStep.error);

    useEffect(() {
      if (isInitializationErrored || isInitializationActive) {
        initTimerStart.value ??= DateTime.now();
      } else {
        initTimerStart.value = null;
      }
      return null;
    }, [isInitializationErrored, isInitializationActive]);

    UnifiedActivityBanner? activityBanner;
    if (isInitializationErrored) {
      activityBanner = UnifiedActivityBanner(
        icon: FIcons.triangleAlert,
        title: Strings.dataOperationsTitle,
        status: Strings.initializationError,
        secondaryStatus:
            initializationErrorMessage ??
            Strings.initializationErrorDescription,
        indeterminate: true,
        startTime: initTimerStart.value,
        isError: true,
        onRetry: () =>
            ref.read(initializationStateProvider.notifier).initialize(),
      );
    } else if (isInitializationActive) {
      const stages = [
        InitializationStep.downloading,
        InitializationStep.parsing,
        InitializationStep.aggregating,
        InitializationStep.cleaning,
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
          FIcons.download,
        ),
        InitializationStep.parsing => (
          Strings.initializationParsing,
          Strings.initializationParsingDescription,
          FIcons.fileDigit,
        ),
        InitializationStep.aggregating => (
          Strings.initializationAggregatingTitle,
          Strings.initializationAggregatingDescription,
          FIcons.database,
        ),
        InitializationStep.cleaning => (
          Strings.initializationInProgress,
          Strings.initializationDescription,
          FIcons.loader,
        ),
        _ => (
          Strings.initializationInProgress,
          Strings.initializationDescription,
          FIcons.loader,
        ),
      };
      activityBanner = UnifiedActivityBanner(
        icon: icon,
        title: Strings.dataOperationsTitle,
        status: status,
        secondaryStatus: description,
        progressValue: initProgress,
        progressLabel: initProgress != null
            ? Strings.dataOperationsProgressLabel(initProgress * 100, status)
            : null,
        indeterminate: initProgress == null,
        startTime: initTimerStart.value,
      );
    } else if (syncProgress.phase != SyncPhase.idle) {
      final presenter = SyncStatusPresenter(syncProgress);
      IconData icon;
      String status;
      String? description;
      bool indeterminate = true;
      double? progressValue;
      Duration? eta;
      var isError = false;

      switch (syncProgress.phase) {
        case SyncPhase.waitingNetwork:
          icon = FIcons.wifiOff;
          status = Strings.dataOperationsWaitingNetwork;
          description = Strings.syncWaitingNetwork;
          break;
        case SyncPhase.checking:
          icon = FIcons.search;
          status = Strings.dataOperationsCheckingUpdates;
          description = Strings.syncCheckingUpdates;
          break;
        case SyncPhase.downloading:
          icon = FIcons.download;
          status = Strings.syncBannerDownloadingTitle;
          description = Strings.syncDownloadingSource(
            syncProgress.subject ?? Strings.data,
          );
          indeterminate = false;
          progressValue = syncProgress.progress;
          eta = syncProgress.estimatedRemaining;
          break;
        case SyncPhase.applying:
          icon = FIcons.databaseZap;
          status = Strings.syncBannerApplyingTitle;
          description = Strings.syncApplyingUpdate;
          break;
        case SyncPhase.success:
          icon = FIcons.circleCheck;
          status = Strings.syncBannerSuccessTitle;
          description =
              presenter.successDescription ?? Strings.syncDatabaseUpdated;
          indeterminate = false;
          progressValue = 1;
          break;
        case SyncPhase.error:
          icon = FIcons.triangleAlert;
          status = Strings.syncBannerErrorTitle;
          description = presenter.errorDescription ?? Strings.syncFailedMessage;
          isError = true;
          break;
        case SyncPhase.idle:
          icon = FIcons.loader;
          status = Strings.dataOperationsIdle;
          break;
      }

      activityBanner = UnifiedActivityBanner(
        icon: icon,
        title: Strings.dataOperationsTitle,
        status: status,
        secondaryStatus: description,
        progressValue: progressValue,
        progressLabel: progressValue != null
            ? Strings.dataOperationsProgressLabel(progressValue * 100, status)
            : null,
        indeterminate: indeterminate,
        startTime: syncProgress.startTime,
        estimatedRemaining: eta,
        isError: isError,
        onRetry: isError ? () => triggerSync(force: true) : null,
      );
    }

    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (navigationShell.currentIndex != 0) {
          onTabChanged(0);
        }
      },
      child: FScaffold(
        header: FHeader(
          title: Text(titles[navigationShell.currentIndex]),
          suffixes: [
            Testable(
              id: TestTags.navSettings,
              child: FHeaderAction(
                icon: const Icon(FIcons.settings),
                onPress: () => const SettingsRoute().push<void>(context),
              ),
            ),
          ],
        ),
        footer: FBottomNavigationBar(
          index: navigationShell.currentIndex,
          onChange: onTabChanged,
          children: const [
            FBottomNavigationBarItem(
              icon: Icon(FIcons.scan),
              label: Text(Strings.scanner),
            ),
            FBottomNavigationBarItem(
              icon: Icon(FIcons.database),
              label: Text(Strings.explorer),
            ),
          ],
        ),
        child: Column(
          children: [
            if (activityBanner != null)
              activityBanner.animate(effects: AppAnimations.bannerEnter),
            Expanded(
              // The navigationShell acts as the body. It contains the IndexedStack internally.
              child: navigationShell,
            ),
          ],
        ),
      ),
    );
  }
}

class SyncStatusPresenter {
  const SyncStatusPresenter(this.progress);

  final SyncProgress progress;

  String? get successDescription {
    switch (progress.code) {
      case SyncStatusCode.successAlreadyCurrent:
        return Strings.syncUpToDate;
      case SyncStatusCode.successUpdatesApplied:
        return Strings.syncDatabaseUpdated;
      case SyncStatusCode.successVerified:
        return Strings.syncContentVerified;
      default:
        return null;
    }
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
