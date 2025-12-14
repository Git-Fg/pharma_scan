import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/providers/app_bar_provider.dart';
import 'package:pharma_scan/core/providers/navigation_provider.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/shadcn_bottom_nav.dart';
import 'package:pharma_scan/features/home/widgets/unified_activity_banner.dart';
import 'package:pharma_scan/features/home/viewmodels/activity_banner_viewmodel.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Scaffold shell that encapsulates the main app structure with consistent navigation and header logic.
///
/// This widget centralizes:
/// - Keyboard detection and bottom navigation visibility
/// - AppBar configuration through useAppHeader
/// - Bottom navigation with tab reselection handling
/// - Activity banner integration
///
/// Usage:
/// ```dart
/// ScaffoldShell(
///   child: AutoTabsRouter(
///     routes: const [Tab1Route(), Tab2Route()],
///     builder: (context, child) => child,
///   ),
/// )
/// ```
class ScaffoldShell extends ConsumerWidget {
  const ScaffoldShell({
    required this.child,
    this.showBottomNav = true,
    this.resizeToAvoidBottomInset = true,
    super.key,
  });

  final Widget child;
  final bool showBottomNav;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keyboard detection logic
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final rootKeyboardHeight = rootNavigator.context != context
        ? MediaQuery.viewInsetsOf(rootNavigator.context).bottom
        : 0.0;
    final isKeyboardOpen = keyboardHeight > 0 || rootKeyboardHeight > 0;

    // Tab navigation setup
    final tabsRouter = AutoTabsRouter.of(context);
    void handleReselect(int index) {
      tabsRouter.stackRouterOfIndex(index)?.popUntilRoot();
      ref.read(tabReselectionProvider.notifier).ping(index);
    }

    // AppBar configuration
    final appBarConfig = ref.watch(appBarStateProvider);
    final canPop = AutoRouter.of(context).canPop();

    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: context.colors.background,
      appBar: appBarConfig.isVisible
          ? PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: AppBar(
                leading: appBarConfig.showBackButton || canPop
                    ? ShadIconButton.ghost(
                        icon: const Icon(LucideIcons.arrowLeft),
                        onPressed: () => AutoRouter.of(context).maybePop(),
                      )
                    : null,
                title: appBarConfig.title,
                actions: appBarConfig.actions,
              ),
            )
          : null,
      bottomNavigationBar: (showBottomNav && !isKeyboardOpen)
          ? ShadcnBottomNav(
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
            )
          : null,
      body: child,
    );
  }
}

/// ActivityBannerWrapper that handles the UnifiedActivityBanner positioning
///
/// This widget provides consistent activity banner integration across the app
/// by managing SafeArea and positioning logic.
class ActivityBannerWrapper extends ConsumerWidget {
  const ActivityBannerWrapper({
    required this.child,
    this.bannerState,
    super.key,
  });

  final Widget child;
  final ActivityBannerState? bannerState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        if (bannerState != null)
          SafeArea(
            bottom: false,
            child: UnifiedActivityBanner(
              icon: bannerState!.icon,
              title: bannerState!.title,
              status: bannerState!.status,
              secondaryStatus: bannerState!.secondaryStatus,
              progressValue: bannerState!.progressValue,
              progressLabel: bannerState!.progressLabel,
              indeterminate: bannerState!.indeterminate,
              isError: bannerState!.isError,
              onRetry: bannerState!.onRetry,
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}