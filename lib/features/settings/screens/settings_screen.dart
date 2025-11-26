import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/utils/adaptive_overlay.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/providers/theme_provider.dart';
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/features/home/providers/sync_provider.dart';

class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isResetting = useState(false);
    final isCheckingUpdates = useState(false);

    Future<void> performReset() async {
      Navigator.of(context).pop();
      isResetting.value = true;

      try {
        await ref
            .read(dataInitializationServiceProvider)
            .initializeDatabase(forceRefresh: true);

        if (context.mounted) {
          ShadSonner.of(context).show(
            const ShadToast(
              title: Text(Strings.resetComplete),
              description: Text(Strings.resetSuccess),
            ),
          );
        }
      } catch (_) {
        if (context.mounted) {
          final sonner = ShadSonner.of(context);
          final toastId = DateTime.now().millisecondsSinceEpoch;
          sonner.show(
            ShadToast.destructive(
              id: toastId,
              title: const Text(Strings.resetError),
              description: const Text(Strings.resetErrorDescription),
              action: ShadButton.outline(
                onPressed: () => sonner.hide(toastId),
                child: const Text(Strings.close),
              ),
            ),
          );
        }
      } finally {
        if (context.mounted) {
          isResetting.value = false;
        }
      }
    }

    void showResetConfirmation() {
      final theme = ShadTheme.of(context);
      final isMobile = MediaQuery.sizeOf(context).width < 600;

      showAdaptiveOverlay(
        context: context,
        builder: (overlayContext) {
          if (isMobile) {
            // Mobile : ShadCard dans BottomSheet
            return ShadCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Strings.resetDatabaseTitle, style: theme.textTheme.h4),
                  const Gap(12),
                  Text(
                    Strings.resetDatabaseDescription,
                    style: theme.textTheme.muted,
                  ),
                  const Gap(24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ShadButton.outline(
                        onPressed: () => Navigator.of(overlayContext).pop(),
                        child: const Text(Strings.cancel),
                      ),
                      const Gap(8),
                      ShadButton.destructive(
                        onPressed: () {
                          Navigator.of(overlayContext).pop();
                          performReset();
                        },
                        child: const Text(Strings.confirm),
                      ),
                    ],
                  ),
                ],
              ),
            );
          } else {
            // Desktop : ShadDialog
            return ShadDialog.alert(
              title: const Text(Strings.resetDatabaseTitle),
              description: const Text(Strings.resetDatabaseDescription),
              actions: [
                ShadButton.outline(
                  onPressed: () => Navigator.of(overlayContext).pop(),
                  child: const Text(Strings.cancel),
                ),
                ShadButton.destructive(
                  onPressed: () {
                    Navigator.of(overlayContext).pop();
                    performReset();
                  },
                  child: const Text(Strings.confirm),
                ),
              ],
            );
          }
        },
      );
    }

    Future<void> runManualSync() async {
      if (isCheckingUpdates.value) return;
      isCheckingUpdates.value = true;

      showAdaptiveOverlay(
        context: context,
        isDismissible: false,
        builder: (overlayContext) => _SyncProgressDialog(
          isMobile: MediaQuery.sizeOf(context).width < 600,
        ),
      );

      try {
        final updated = await ref
            .read(syncControllerProvider.notifier)
            .startSync(force: true);
        if (!context.mounted) return;
        ShadSonner.of(context).show(
          ShadToast(
            title: Text(updated ? Strings.bdpmSynced : Strings.noNewUpdates),
            description: Text(
              updated
                  ? Strings.latestBdpmDataApplied
                  : Strings.localDataUpToDate,
            ),
          ),
        );
      } catch (_) {
        if (!context.mounted) return;
        final sonner = ShadSonner.of(context);
        final toastId = DateTime.now().millisecondsSinceEpoch;
        sonner.show(
          ShadToast.destructive(
            id: toastId,
            title: const Text(Strings.syncFailed),
            description: const Text(Strings.unableToCheckBdpmUpdates),
            action: ShadButton.outline(
              onPressed: () => sonner.hide(toastId),
              child: const Text(Strings.close),
            ),
          ),
        );
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          isCheckingUpdates.value = false;
        }
      }
    }

    final theme = ShadTheme.of(context);
    final frequencyState = ref.watch(appPreferencesProvider);
    final updateFrequency = frequencyState.value ?? UpdateFrequency.daily;
    final isFrequencyLoading = frequencyState.isLoading;
    final themeAsync = ref.watch(themeProvider);
    final currentTheme = themeSettingFromThemeMode(
      themeAsync.value ?? ThemeMode.system,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.settings),
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.foreground),
      ),
      backgroundColor: theme.colorScheme.background,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Strings.appearance, style: theme.textTheme.h4),
                const Gap(16),
                ShadRadioGroup<ThemeSetting>(
                  initialValue: currentTheme,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(themeProvider.notifier).setTheme(value);
                    }
                  },
                  items: const [
                    ShadRadio<ThemeSetting>(
                      value: ThemeSetting.system,
                      label: Text(Strings.systemTheme),
                    ),
                    ShadRadio<ThemeSetting>(
                      value: ThemeSetting.light,
                      label: Text(Strings.lightTheme),
                    ),
                    ShadRadio<ThemeSetting>(
                      value: ThemeSetting.dark,
                      label: Text(Strings.darkTheme),
                    ),
                  ],
                ),
                const Gap(48),
                Text(Strings.sync, style: theme.textTheme.h4),
                const Gap(16),
                ShadRadioGroup<UpdateFrequency>(
                  initialValue: updateFrequency,
                  onChanged: isFrequencyLoading
                      ? null
                      : (value) async {
                          if (value == null) return;
                          await ref
                              .read(appPreferencesProvider.notifier)
                              .setUpdateFrequency(value);
                        },
                  items: const [
                    ShadRadio<UpdateFrequency>(
                      value: UpdateFrequency.none,
                      label: Text(Strings.never),
                    ),
                    ShadRadio<UpdateFrequency>(
                      value: UpdateFrequency.daily,
                      label: Text(Strings.daily),
                    ),
                    ShadRadio<UpdateFrequency>(
                      value: UpdateFrequency.weekly,
                      label: Text(Strings.weekly),
                    ),
                    ShadRadio<UpdateFrequency>(
                      value: UpdateFrequency.monthly,
                      label: Text(Strings.monthly),
                    ),
                  ],
                ),
                const Gap(8),
                Text(
                  Strings.determinesCheckFrequency,
                  style: theme.textTheme.muted,
                ),
                const Gap(48),
                Text(Strings.data, style: theme.textTheme.h4),
                const Gap(16),
                Semantics(
                  button: true,
                  label: isCheckingUpdates.value
                      ? Strings.checkingUpdatesTitle
                      : Strings.checkUpdatesNow,
                  enabled: !isCheckingUpdates.value,
                  child: ShadButton(
                    onPressed: isCheckingUpdates.value ? null : runManualSync,
                    leading: const Icon(LucideIcons.refreshCw, size: 16),
                    child: Text(
                      isCheckingUpdates.value
                          ? Strings.checkingUpdatesInProgress
                          : Strings.checkUpdatesNow,
                    ),
                  ),
                ),
                const Gap(12),
                Semantics(
                  button: true,
                  label:
                      'Forcer la réinitialisation complète de la base de données',
                  hint:
                      'Cette action supprimera toutes les données locales et les re-téléchargera',
                  child: ShadButton.destructive(
                    onPressed: showResetConfirmation,
                    leading: const Icon(LucideIcons.databaseZap, size: 16),
                    child: const Text(Strings.forceReset),
                  ),
                ),
                const Gap(8),
                Text(
                  Strings.forceResetDescription,
                  style: theme.textTheme.muted,
                ),
                const Gap(24),
                Text(Strings.diagnostics, style: theme.textTheme.h4),
                const Gap(12),
                Semantics(
                  button: true,
                  label: Strings.showApplicationLogs,
                  hint: Strings.openDetailedViewForSupport,
                  child: ShadButton.outline(
                    onPressed: () => context.push(AppRoutes.logs),
                    leading: const Icon(LucideIcons.terminal, size: 16),
                    child: const Text(Strings.showLogs),
                  ),
                ),
              ],
            ),
          ),
          if (isResetting.value)
            ColoredBox(
              color: theme.colorScheme.background.withValues(alpha: 0.8),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [ShadProgress(), Gap(16), Text(Strings.resetting)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SyncProgressDialog extends StatelessWidget {
  const _SyncProgressDialog({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    if (isMobile) {
      // Mobile : ShadCard dans BottomSheet
      return ShadCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Strings.checkUpdates, style: theme.textTheme.h4),
            const Gap(16),
            const ShadProgress(),
            const Gap(12),
            Text(
              Strings.pleaseWaitSync,
              style: theme.textTheme.muted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      // Desktop : ShadDialog
      return ShadDialog(
        title: const Text(Strings.checkUpdatesTitle),
        description: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(16),
            const ShadProgress(),
            const Gap(12),
            Text(
              Strings.pleaseWaitSync,
              style: theme.textTheme.muted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: const [],
      );
    }
  }
}
