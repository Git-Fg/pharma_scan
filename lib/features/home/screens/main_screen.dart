// lib/features/home/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/core/utils/app_animations.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/home/providers/sync_status_provider.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:pharma_scan/core/services/sync_service.dart';
import 'package:pharma_scan/features/explorer/providers/group_cluster_provider.dart';
import 'package:pharma_scan/features/explorer/providers/group_summary_provider.dart';
import 'package:pharma_scan/features/explorer/providers/search_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  void _onTabChanged(int index) {
    // "goBranch" switches the tab.
    // "initialLocation: index == navigationShell.currentIndex" implements the
    // standard behavior: if you tap the active tab, it pops to the root of that tab.
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<bool> _triggerSync({bool force = false}) {
    return ref
        .read(syncServiceProvider)
        .checkForUpdates(
          resolveFrequency: () => ref.read(appPreferencesProvider.future),
          reportStatus: (progress) =>
              ref.read(syncStatusProvider.notifier).updateStatus(progress),
          force: force,
        )
        .catchError((_) => false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerSync();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final titles = [Strings.scanner, Strings.explorer];
    final syncProgress = ref.watch(syncStatusProvider);
    final initState = ref.watch(initializationStateProvider);

    // WHY: Listen for sync success to invalidate data providers
    // When sync completes successfully, Explorer and Search screens need fresh data
    ref.listen(syncStatusProvider, (previous, next) {
      final presenter = SyncStatusPresenter(next);
      if (next.phase == SyncPhase.success &&
          previous?.phase != SyncPhase.success) {
        // Invalidate caches to force reload of fresh database content
        ref.invalidate(searchCandidatesProvider);
        ref.invalidate(groupClusterProvider);
        ref.invalidate(groupSummaryProvider);

        // Show success toast notification
        if (mounted) {
          ShadSonner.of(context).show(
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
        if (mounted) {
          final sonner = ShadSonner.of(context);
          final toastId = DateTime.now().millisecondsSinceEpoch;
          sonner.show(
            ShadToast.destructive(
              id: toastId,
              title: const Text(Strings.syncFailed),
              description: Text(
                presenter.errorDescription ?? Strings.syncFailedMessage,
              ),
              action: ShadButton.outline(
                onPressed: () => sonner.hide(toastId),
                child: const Text(Strings.close),
              ),
            ),
          );
        }
      }
    });

    return PopScope(
      canPop: widget.navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (widget.navigationShell.currentIndex != 0) {
          _onTabChanged(0);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            titles[widget.navigationShell.currentIndex],
            style: theme.textTheme.h4.copyWith(
              color: theme.colorScheme.foreground,
            ),
          ),
          backgroundColor: theme.colorScheme.background,
          elevation: 0,
          actions: [
            Semantics(
              button: true,
              label: Strings.openSettings,
              child: ShadButton.ghost(
                onPressed: () => context.push(AppRoutes.settings),
                leading: const Icon(LucideIcons.settings, size: 20),
                child: const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (syncProgress.phase != SyncPhase.idle)
                _SyncStatusBanner(
                  progress: syncProgress,
                  onRetry: syncProgress.phase == SyncPhase.error
                      ? () => _triggerSync(force: true)
                      : null,
                ).animate(effects: AppAnimations.bannerEnter),
              if (initState == InitializationState.error)
                _InitializationBanner(
                  onRetry: () => ref
                      .read(initializationStateProvider.notifier)
                      .initialize(),
                ).animate(effects: AppAnimations.bannerEnter),
              Expanded(
                // The navigationShell acts as the body. It contains the IndexedStack internally.
                child: widget.navigationShell,
              ),
            ],
          ),
        ),
        // WHY: Custom bottom navigation bar using Shadcn theme styling.
        // Positioned at bottom for ergonomic thumb access.
        // Enhanced with shadow and increased padding for better visibility.
        // SafeArea ensures proper spacing above system navigation bar on Android.
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.background,
              border: Border(top: BorderSide(color: theme.colorScheme.border)),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.foreground.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(0, LucideIcons.scan, Strings.scanner, theme),
                _buildNavItem(1, LucideIcons.database, Strings.explorer, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    ShadThemeData theme,
  ) {
    final isSelected = widget.navigationShell.currentIndex == index;
    // Animate the scale of the selected item
    return GestureDetector(
      onTap: () => _onTabChanged(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: isSelected
            ? BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.mutedForeground,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.small.copyWith(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.mutedForeground,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InitializationBanner extends ConsumerWidget {
  final VoidCallback onRetry;

  const _InitializationBanner({required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final errorMessage = ref.watch(initializationErrorMessageProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ShadCard(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded),
            const SizedBox(width: 8),
            Expanded(
              child: Text(Strings.updateError, style: theme.textTheme.h4),
            ),
          ],
        ),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Strings.updateLimited, style: theme.textTheme.muted),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(errorMessage, style: theme.textTheme.small),
              ),
          ],
        ),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Semantics(
              button: true,
              label: Strings.openSettings,
              child: ShadButton.outline(
                onPressed: () => context.push(AppRoutes.settings),
                child: const Text(Strings.openSettings),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: Strings.retryUpdate,
              child: ShadButton(
                onPressed: onRetry,
                child: const Text(Strings.retry),
              ),
            ),
          ],
        ),
        child: const SizedBox.shrink(),
      ),
    );
  }
}

class _SyncStatusBanner extends StatelessWidget {
  const _SyncStatusBanner({required this.progress, this.onRetry});

  final SyncProgress progress;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final bannerData = SyncStatusPresenter(progress).toBannerData();
    if (bannerData == null) return const SizedBox.shrink();

    final showProgressIndicator =
        bannerData.showProgress && bannerData.progressValue != null;
    final hasDescription =
        bannerData.description != null || showProgressIndicator;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ShadCard(
        title: Row(
          children: [
            Icon(bannerData.icon, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(bannerData.title, style: theme.textTheme.h4)),
          ],
        ),
        description: hasDescription
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bannerData.description != null)
                    Text(bannerData.description!, style: theme.textTheme.muted),
                  if (showProgressIndicator)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ShadProgress(value: bannerData.progressValue!),
                    ),
                ],
              )
            : null,
        footer: bannerData.showRetry && onRetry != null
            ? Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  button: true,
                  label: Strings.retrySync,
                  child: ShadButton.outline(
                    onPressed: onRetry,
                    child: const Text(Strings.retry),
                  ),
                ),
              )
            : null,
        child: const SizedBox.shrink(),
      ),
    );
  }
}

class SyncBannerData {
  const SyncBannerData({
    required this.icon,
    required this.title,
    this.description,
    this.showProgress = false,
    this.progressValue,
    this.showRetry = false,
  });

  final IconData icon;
  final String title;
  final String? description;
  final bool showProgress;
  final double? progressValue;
  final bool showRetry;
}

class SyncStatusPresenter {
  const SyncStatusPresenter(this.progress);

  final SyncProgress progress;

  SyncBannerData? toBannerData() {
    switch (progress.phase) {
      case SyncPhase.idle:
        return null;
      case SyncPhase.waitingNetwork:
        return const SyncBannerData(
          icon: LucideIcons.wifiOff,
          title: Strings.syncBannerWaitingNetworkTitle,
          description: Strings.syncWaitingNetwork,
        );
      case SyncPhase.checking:
        return const SyncBannerData(
          icon: LucideIcons.search,
          title: Strings.syncBannerCheckingTitle,
          description: Strings.syncCheckingUpdates,
        );
      case SyncPhase.downloading:
        return SyncBannerData(
          icon: LucideIcons.download,
          title: Strings.syncBannerDownloadingTitle,
          description: Strings.syncDownloadingSource(
            progress.subject ?? Strings.data,
          ),
          showProgress: progress.progress != null,
          progressValue: progress.progress,
        );
      case SyncPhase.applying:
        return const SyncBannerData(
          icon: LucideIcons.databaseZap,
          title: Strings.syncBannerApplyingTitle,
          description: Strings.syncApplyingUpdate,
        );
      case SyncPhase.success:
        return SyncBannerData(
          icon: LucideIcons.circleCheck,
          title: Strings.syncBannerSuccessTitle,
          description: successDescription ?? Strings.syncDatabaseUpdated,
        );
      case SyncPhase.error:
        return SyncBannerData(
          icon: LucideIcons.triangleAlert,
          title: Strings.syncBannerErrorTitle,
          description: errorDescription ?? Strings.syncFailedMessage,
          showRetry: true,
        );
    }
  }

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
