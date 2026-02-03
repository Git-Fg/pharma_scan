import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/app/router/app_router.dart';

import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/scaffold_shell.dart';
import 'package:pharma_scan/core/providers/sync_provider.dart';
import 'package:pharma_scan/core/providers/activity_banner_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

@RoutePage()
class MainScreen extends HookConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityBannerState = ref.watch(activityBannerProvider);

    ref.listen(syncControllerProvider, (previous, next) {
      final presenter = SyncStatusPresenter(next);
      if (next.phase == .success && previous?.phase != .success) {
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
      } else if (next.phase == .error && previous?.phase != .error) {
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
