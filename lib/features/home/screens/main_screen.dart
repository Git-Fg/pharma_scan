// lib/features/home/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/utils/app_animations.dart';
import 'package:pharma_scan/features/home/providers/sync_status_provider.dart';
import 'package:pharma_scan/core/services/sync_service.dart';
import 'package:pharma_scan/features/explorer/screens/database_screen.dart';
import 'package:pharma_scan/features/explorer/providers/group_cluster_provider.dart';
import 'package:pharma_scan/features/explorer/providers/group_summary_provider.dart';
import 'package:pharma_scan/features/explorer/providers/search_provider.dart';
import 'package:pharma_scan/features/scanner/screens/camera_screen.dart';
import 'package:pharma_scan/features/settings/screens/settings_screen.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum InitializationState { initializing, success, error }

class MainScreen extends ConsumerStatefulWidget {
  final InitializationState initState;
  final VoidCallback onRetryInitialization;

  const MainScreen({
    required this.initState,
    required this.onRetryInitialization,
    super.key,
  });

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _selectedIndex = 0;
  final GlobalKey<NavigatorState> _scannerNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _explorerNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<State<CameraScreen>> _cameraScreenKey = GlobalKey();
  late final SyncService _syncService = sl<SyncService>();

  void _onTabChanged(int newIndex) {
    setState(() {
      _selectedIndex = newIndex;
    });
    // WHY: Notify CameraScreen when visibility changes to stop/start camera
    CameraScreen.onVisibilityChanged(_cameraScreenKey, newIndex == 0);
  }

  Future<bool> _triggerSync({bool force = false}) {
    return _syncService
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
    final titles = ['Scanner', 'Explorer'];
    final syncProgress = ref.watch(syncStatusProvider);

    // WHY: Listen for sync success to invalidate data providers
    // When sync completes successfully, Explorer and Search screens need fresh data
    ref.listen(syncStatusProvider, (previous, next) {
      if (next.phase == SyncPhase.success) {
        // Invalidate caches to force reload of fresh database content
        ref.invalidate(searchCandidatesProvider);
        ref.invalidate(groupClusterProvider);
        ref.invalidate(groupSummaryProvider);

        // Show success toast notification
        if (mounted) {
          ShadSonner.of(context).show(
            ShadToast(
              title: const Text('Mise à jour terminée'),
              description: Text(next.message ?? 'La base BDPM est à jour.'),
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
              title: const Text('Synchronisation échouée'),
              description: Text(
                next.message ?? 'Impossible de synchroniser les données BDPM.',
              ),
              action: ShadButton.outline(
                onPressed: () => sonner.hide(toastId),
                child: const Text('Fermer'),
              ),
            ),
          );
        }
      }
    });

    // WHY: Each tab has its own Navigator to maintain independent navigation stacks.
    // This allows proper back button handling within each tab.
    final List<Widget> screens = [
      Navigator(
        key: _scannerNavigatorKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => CameraScreen(
              key: _cameraScreenKey,
              isVisible: _selectedIndex == 0,
            ),
          );
        },
      ),
      Navigator(
        key: _explorerNavigatorKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const DatabaseScreen(),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[_selectedIndex],
          style: theme.textTheme.h4.copyWith(
            color: theme.colorScheme.foreground,
          ),
        ),
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        actions: [
          ShadButton.ghost(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            leading: const Icon(LucideIcons.settings, size: 20),
            child: const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (syncProgress.phase != SyncPhase.idle)
            _SyncStatusBanner(
              progress: syncProgress,
              onRetry: syncProgress.phase == SyncPhase.error
                  ? () => _triggerSync(force: true)
                  : null,
            ).animate(effects: AppAnimations.bannerEnter),
          if (widget.initState == InitializationState.error)
            _InitializationBanner(
              onRetry: widget.onRetryInitialization,
            ).animate(effects: AppAnimations.bannerEnter),
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: screens),
          ),
        ],
      ),
      // WHY: Custom bottom navigation bar using Shadcn theme styling.
      // Positioned at bottom for ergonomic thumb access.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.colorScheme.border)),
          color: theme.colorScheme.background,
        ),
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, LucideIcons.scan, 'Scanner', theme),
            _buildNavItem(1, LucideIcons.database, 'Explorer', theme),
          ],
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
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onTabChanged(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.mutedForeground,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.small.copyWith(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.mutedForeground,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _InitializationBanner extends StatelessWidget {
  final VoidCallback onRetry;

  const _InitializationBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ShadCard(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Erreur lors de la mise à jour des données',
                style: theme.textTheme.h4,
              ),
            ),
          ],
        ),
        description: Text(
          'Certaines fonctionnalités peuvent être limitées tant que la base BDPM n’est pas synchronisée.',
          style: theme.textTheme.muted,
        ),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ShadButton.outline(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              child: const Text('Ouvrir les réglages'),
            ),
            const SizedBox(width: 8),
            ShadButton(onPressed: onRetry, child: const Text('Réessayer')),
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

    late final IconData icon;
    late final String title;
    final description = progress.message;

    switch (progress.phase) {
      case SyncPhase.waitingNetwork:
        icon = LucideIcons.wifiOff;
        title = 'Connexion requise';
        break;
      case SyncPhase.checking:
        icon = LucideIcons.search;
        title = 'Recherche de mises à jour';
        break;
      case SyncPhase.downloading:
        icon = LucideIcons.download;
        title = 'Téléchargement BDPM';
        break;
      case SyncPhase.applying:
        icon = LucideIcons.databaseZap;
        title = 'Mise à jour locale';
        break;
      case SyncPhase.success:
        icon = LucideIcons.circleCheck;
        title = 'Synchronisation terminée';
        break;
      case SyncPhase.error:
        icon = LucideIcons.triangleAlert;
        title = 'Synchronisation échouée';
        break;
      case SyncPhase.idle:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ShadCard(
        title: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: theme.textTheme.h4)),
          ],
        ),
        description: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description != null)
              Text(description, style: theme.textTheme.muted),
            if (progress.phase == SyncPhase.downloading &&
                progress.progress != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ShadProgress(value: progress.progress!),
              ),
          ],
        ),
        footer: progress.phase == SyncPhase.error && onRetry != null
            ? Align(
                alignment: Alignment.centerRight,
                child: ShadButton.outline(
                  onPressed: onRetry,
                  child: const Text('Réessayer'),
                ),
              )
            : null,
        child: const SizedBox.shrink(),
      ),
    );
  }
}
