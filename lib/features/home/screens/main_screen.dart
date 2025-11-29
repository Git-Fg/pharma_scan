// lib/features/home/screens/main_screen.dart
import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/utils/app_animations.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/testable.dart';
import 'package:pharma_scan/features/home/models/sync_state.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:pharma_scan/features/home/providers/sync_provider.dart';
import 'package:pharma_scan/features/home/widgets/unified_activity_banner.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

@RoutePage()
class MainScreen extends HookConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          ref
              .read(syncControllerProvider.notifier)
              .startSync()
              .catchError((_) => false),
        );
      });
      return null;
    }, []);

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

    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final rootKeyboardHeight = rootNavigator.context != context
        ? MediaQuery.viewInsetsOf(rootNavigator.context).bottom
        : 0.0;
    final isKeyboardOpen = keyboardHeight > 0 || rootKeyboardHeight > 0;

    ref.listen(syncControllerProvider, (previous, next) {
      final presenter = SyncStatusPresenter(next);
      if (next.phase == SyncPhase.success &&
          previous?.phase != SyncPhase.success) {
        // Show success toast notification
        if (context.mounted) {
          ShadToaster.of(context).show(
            ShadToast(
              title: const Text(Strings.updateCompleted),
              description: Text(
                presenter.successDescription ?? Strings.bdpmUpToDate,
              ),
            ),
          );
        }
      } else if (next.phase == SyncPhase.error &&
          previous?.phase != SyncPhase.error) {
        // Show error toast notification only on transition to error
        if (context.mounted) {
          ShadToaster.of(context).show(
            ShadToast.destructive(
              title: const Text(Strings.syncFailed),
              description: Text(
                presenter.errorDescription ?? Strings.syncFailedMessage,
              ),
            ),
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
        icon: LucideIcons.triangleAlert,
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
      var indeterminate = true;
      double? progressValue;
      Duration? eta;
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
          eta = syncProgress.estimatedRemaining;
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

    return AutoTabsRouter(
      routes: const [ScannerRoute(), ExplorerTabRoute()],
      builder: (BuildContext context, Widget child) {
        final tabsRouter = AutoTabsRouter.of(context);
        return PopScope<Object>(
          canPop: tabsRouter.activeIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (tabsRouter.activeIndex != 0) {
              tabsRouter.setActiveIndex(0);
            }
          },
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            appBar: AppBar(
              title: Text(
                titles[tabsRouter.activeIndex],
                style: ShadTheme.of(context).textTheme.h4,
              ),
              elevation: 0,
              backgroundColor: ShadTheme.of(context).colorScheme.background,
              foregroundColor: ShadTheme.of(context).colorScheme.foreground,
              actions: [
                Testable(
                  id: TestTags.navSettings,
                  child: ShadIconButton.ghost(
                    icon: const Icon(LucideIcons.settings),
                    onPressed: () => context.router.push(const SettingsRoute()),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: isKeyboardOpen
                ? null
                : NavigationBar(
                    selectedIndex: tabsRouter.activeIndex,
                    onDestinationSelected: tabsRouter.setActiveIndex,
                    backgroundColor: ShadTheme.of(
                      context,
                    ).colorScheme.background,
                    indicatorColor: ShadTheme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(LucideIcons.scan),
                        selectedIcon: Icon(
                          LucideIcons.scan,
                          color: ShadTheme.of(context).colorScheme.primary,
                        ),
                        label: Strings.scanner,
                      ),
                      NavigationDestination(
                        icon: const Icon(LucideIcons.database),
                        selectedIcon: Icon(
                          LucideIcons.database,
                          color: ShadTheme.of(context).colorScheme.primary,
                        ),
                        label: Strings.explorer,
                      ),
                    ],
                  ),
            body: Column(
              children: [
                if (activityBanner != null)
                  activityBanner.animate(effects: AppAnimations.bannerEnter),
                Expanded(child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}

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
