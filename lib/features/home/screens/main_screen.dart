import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/providers/navigation_provider.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/shadcn_bottom_nav.dart';
import 'package:pharma_scan/features/home/models/sync_state.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:pharma_scan/features/home/providers/sync_provider.dart';
import 'package:pharma_scan/features/home/viewmodels/activity_banner_viewmodel.dart';
import 'package:pharma_scan/features/home/widgets/unified_activity_banner.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

@RoutePage()
class MainScreen extends HookConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initializationState = ref.watch(initializationStateProvider);

    useEffect(() {
      if (initializationState != InitializationState.success) {
        return null;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(
          ref.read(syncControllerProvider.notifier).startSync(),
        );
      });
      return null;
    }, [initializationState]);

    final activityBannerState = ref.watch(activityBannerViewModelProvider);

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
        if (context.mounted) {
          ShadToaster.of(context).show(
            ShadToast(
              title: const Text(Strings.updateCompleted),
              description: Text(
                presenter.successDescription ?? Strings.bdpmUpToDate,
              ),
              alignment: Alignment.bottomCenter,
            ),
          );
        }
      } else if (next.phase == SyncPhase.error &&
          previous?.phase != SyncPhase.error) {
        if (context.mounted) {
          ShadToaster.of(context).show(
            ShadToast.destructive(
              title: const Text(Strings.syncFailed),
              description: Text(
                presenter.errorDescription ?? Strings.syncFailedMessage,
              ),
              alignment: Alignment.bottomCenter,
            ),
          );
        }
      }
    });

    return AutoTabsRouter(
      routes: const [ScannerTabRoute(), ExplorerTabRoute(), RestockRoute()],
      builder: (BuildContext context, Widget child) {
        final tabsRouter = AutoTabsRouter.of(context);
        void handleReselect(int index) {
          tabsRouter.stackRouterOfIndex(index)?.popUntilRoot();
          ref.read(tabReselectionProvider.notifier).ping(index);
        }

        // WARNING: PopScope usage - see flutter-navigation.mdc section 11
        return PopScope<Object>(
          canPop:
              tabsRouter.activeIndex == 0 &&
              !tabsRouter.current.router.canPop(),
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (tabsRouter.current.router.canPop()) {
              tabsRouter.current.router.pop();
              return;
            }
            if (tabsRouter.activeIndex != 0) {
              tabsRouter.setActiveIndex(0);
            }
          },
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            backgroundColor: context.shadColors.background,
            bottomNavigationBar: isKeyboardOpen
                ? null
                : ShadcnBottomNav(
                    currentIndex: tabsRouter.activeIndex,
                    onTap: (index) {
                      if (tabsRouter.activeIndex == index) {
                        handleReselect(index);
                        return;
                      }
                      tabsRouter.setActiveIndex(index);
                    },
                    onReselect: handleReselect,
                    items: const [
                      (
                        icon: LucideIcons.scan,
                        activeIcon: LucideIcons.scan,
                        label: Strings.scanner,
                        testId: TestTags.navScanner,
                      ),
                      (
                        icon: LucideIcons.database,
                        activeIcon: LucideIcons.database,
                        label: Strings.explorer,
                        testId: TestTags.navExplorer,
                      ),
                      (
                        icon: LucideIcons.list,
                        activeIcon: LucideIcons.list,
                        label: Strings.restockTabLabel,
                        testId: TestTags.navRestock,
                      ),
                    ],
                  ),
            body: Column(
              children: [
                if (activityBannerState != null)
                  SafeArea(
                    bottom: false,
                    child: UnifiedActivityBanner(
                      icon: activityBannerState.icon,
                      title: activityBannerState.title,
                      status: activityBannerState.status,
                      secondaryStatus: activityBannerState.secondaryStatus,
                      progressValue: activityBannerState.progressValue,
                      progressLabel: activityBannerState.progressLabel,
                      indeterminate: activityBannerState.indeterminate,
                      isError: activityBannerState.isError,
                      onRetry: activityBannerState.onRetry,
                    ),
                  ),
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
