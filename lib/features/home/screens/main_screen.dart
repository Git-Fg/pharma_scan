import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/scaffold_shell.dart';
import 'package:pharma_scan/features/home/models/sync_state.dart';
import 'package:pharma_scan/features/home/providers/sync_provider.dart';
import 'package:pharma_scan/features/home/viewmodels/activity_banner_viewmodel.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

@RoutePage()
class MainScreen extends HookConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityBannerState = ref.watch(activityBannerViewModelProvider);

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
        return ScaffoldShell(
          child: ActivityBannerWrapper(
            bannerState: activityBannerState,
            child: child,
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
      SyncStatusCode.error =>
        null,
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
