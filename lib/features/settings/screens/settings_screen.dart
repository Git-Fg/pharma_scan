import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:forui/forui.dart';
import 'package:pharma_scan/core/utils/adaptive_overlay.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/providers/theme_provider.dart';
import 'package:pharma_scan/core/router/routes.dart';
import 'package:pharma_scan/features/home/providers/sync_provider.dart';

class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeController = useMemoized(
      FSelectGroupController<ThemeSetting>.radio,
    );
    final frequencyController = useMemoized(
      FSelectGroupController<UpdateFrequency>.radio,
    );

    final frequencyState = ref.watch(appPreferencesProvider);
    final isFrequencyLoading = frequencyState.isLoading;
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
          showFToast(
            context: context,
            title: const Text(Strings.resetComplete),
            description: const Text(Strings.resetSuccess),
            icon: const Icon(FIcons.check),
          );
        }
      } catch (_) {
        if (context.mounted) {
          showFToast(
            context: context,
            title: const Text(Strings.resetError),
            description: const Text(Strings.resetErrorDescription),
            icon: const Icon(FIcons.triangleAlert),
          );
        }
      } finally {
        if (context.mounted) {
          isResetting.value = false;
        }
      }
    }

    void showResetConfirmation() {
      final isMobile = MediaQuery.sizeOf(context).width < 600;

      showAdaptiveOverlay<void>(
        context: context,
        builder: (overlayContext) {
          if (isMobile) {
            // Mobile : FCard dans BottomSheet
            return FCard.raw(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Strings.resetDatabaseTitle,
                      style: context.theme.typography.xl2, // h4 equivalent
                    ),
                    const Gap(12),
                    Text(
                      Strings.resetDatabaseDescription,
                      style: context.theme.typography.sm.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                    const Gap(24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FButton(
                          style: FButtonStyle.outline(),
                          onPress: () => Navigator.of(overlayContext).pop(),
                          child: const Text(Strings.cancel),
                        ),
                        const Gap(8),
                        FButton(
                          style: FButtonStyle.primary(),
                          onPress: () {
                            Navigator.of(overlayContext).pop();
                            performReset();
                          },
                          child: const Text(Strings.confirm),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          } else {
            // Desktop : FDialog
            return FDialog(
              title: Text(
                Strings.resetDatabaseTitle,
                style: context.theme.typography.xl2,
              ),
              body: Text(
                Strings.resetDatabaseDescription,
                style: context.theme.typography.base,
              ),
              actions: [
                FButton(
                  style: FButtonStyle.outline(),
                  onPress: () => Navigator.of(overlayContext).pop(),
                  child: const Text(Strings.cancel),
                ),
                FButton(
                  style: FButtonStyle.primary(),
                  onPress: () {
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

      unawaited(
        showAdaptiveOverlay<void>(
          context: context,
          isDismissible: false,
          builder: (overlayContext) => _SyncProgressDialog(
            isMobile: MediaQuery.sizeOf(context).width < 600,
          ),
        ),
      );

      try {
        final updated = await ref
            .read(syncControllerProvider.notifier)
            .startSync(force: true);
        if (!context.mounted) return;
        showFToast(
          context: context,
          title: Text(updated ? Strings.bdpmSynced : Strings.noNewUpdates),
          description: Text(
            updated ? Strings.latestBdpmDataApplied : Strings.localDataUpToDate,
          ),
          icon: updated ? const Icon(FIcons.check) : null,
        );
      } catch (_) {
        if (!context.mounted) return;
        showFToast(
          context: context,
          title: const Text(Strings.syncFailed),
          description: const Text(Strings.unableToCheckBdpmUpdates),
          icon: const Icon(FIcons.triangleAlert),
        );
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          isCheckingUpdates.value = false;
        }
      }
    }

    return FScaffold(
      header: FHeader.nested(
        title: Text(
          Strings.settings,
          style: context.theme.typography.xl2, // h4 equivalent
        ),
        prefixes: [FHeaderAction.back(onPress: () => context.pop())],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Strings.appearance,
                  style: context.theme.typography.xl2, // h4 equivalent
                ),
                const Gap(16),
                FSelectGroup<ThemeSetting>(
                  controller: themeController,
                  onChange: (values) {
                    if (values.isNotEmpty) {
                      ref.read(themeProvider.notifier).setTheme(values.first);
                    }
                  },
                  children: [
                    FRadio.grouped<ThemeSetting>(
                      value: ThemeSetting.system,
                      label: const Text(Strings.systemTheme),
                    ),
                    FRadio.grouped<ThemeSetting>(
                      value: ThemeSetting.light,
                      label: const Text(Strings.lightTheme),
                    ),
                    FRadio.grouped<ThemeSetting>(
                      value: ThemeSetting.dark,
                      label: const Text(Strings.darkTheme),
                    ),
                  ],
                ),
                const Gap(48),
                Text(
                  Strings.sync,
                  style: context.theme.typography.xl2, // h4 equivalent
                ),
                const Gap(16),
                FSelectGroup<UpdateFrequency>(
                  controller: frequencyController,
                  onChange: isFrequencyLoading
                      ? null
                      : (values) async {
                          if (values.isEmpty) return;
                          await ref
                              .read(appPreferencesProvider.notifier)
                              .setUpdateFrequency(values.first);
                        },
                  children: [
                    FRadio.grouped<UpdateFrequency>(
                      value: UpdateFrequency.none,
                      label: const Text(Strings.never),
                    ),
                    FRadio.grouped<UpdateFrequency>(
                      value: UpdateFrequency.daily,
                      label: const Text(Strings.daily),
                    ),
                    FRadio.grouped<UpdateFrequency>(
                      value: UpdateFrequency.weekly,
                      label: const Text(Strings.weekly),
                    ),
                    FRadio.grouped<UpdateFrequency>(
                      value: UpdateFrequency.monthly,
                      label: const Text(Strings.monthly),
                    ),
                  ],
                ),
                const Gap(8),
                Text(
                  Strings.determinesCheckFrequency,
                  style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
                const Gap(48),
                Text(
                  Strings.data,
                  style: context.theme.typography.xl2, // h4 equivalent
                ),
                const Gap(16),
                Semantics(
                  button: true,
                  label: isCheckingUpdates.value
                      ? Strings.checkingUpdatesTitle
                      : Strings.checkUpdatesNow,
                  enabled: !isCheckingUpdates.value,
                  child: FButton(
                    style: FButtonStyle.secondary(),
                    onPress: isCheckingUpdates.value ? null : runManualSync,
                    prefix: const Icon(FIcons.refreshCw, size: 16),
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
                  child: FButton(
                    style: FButtonStyle.primary(),
                    onPress: showResetConfirmation,
                    prefix: const Icon(FIcons.databaseZap, size: 16),
                    child: const Text(Strings.forceReset),
                  ),
                ),
                const Gap(8),
                Text(
                  Strings.forceResetDescription,
                  style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
                const Gap(24),
                Text(
                  Strings.diagnostics,
                  style: context.theme.typography.xl2, // h4 equivalent
                ),
                const Gap(12),
                Semantics(
                  button: true,
                  label: Strings.showApplicationLogs,
                  hint: Strings.openDetailedViewForSupport,
                  child: FButton(
                    style: FButtonStyle.outline(),
                    onPress: () => const LogsRoute().push<void>(context),
                    prefix: const Icon(FIcons.terminal, size: 16),
                    child: const Text(Strings.showLogs),
                  ),
                ),
              ],
            ),
          ),
          if (isResetting.value)
            ColoredBox(
              color: context.theme.colors.background.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 4.0,
                      child: LinearProgressIndicator(
                        backgroundColor: context.theme.colors.muted,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.theme.colors.primary,
                        ),
                        minHeight: 4.0,
                      ),
                    ),
                    const Gap(16),
                    Text(
                      Strings.resetting,
                      style: context.theme.typography.base,
                    ),
                  ],
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
    if (isMobile) {
      // Mobile : FCard dans BottomSheet
      return FCard.raw(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Strings.checkUpdates,
                style: context.theme.typography.xl2, // h4 equivalent
              ),
              const Gap(16),
              SizedBox(
                height: 4.0,
                child: LinearProgressIndicator(
                  backgroundColor: context.theme.colors.muted,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.theme.colors.primary,
                  ),
                  minHeight: 4.0,
                ),
              ),
              const Gap(12),
              Text(
                Strings.pleaseWaitSync,
                style: context.theme.typography.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Desktop : FDialog
      return FDialog(
        title: Text(
          Strings.checkUpdatesTitle,
          style: context.theme.typography.xl2,
        ),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(16),
            SizedBox(
              height: 4.0,
              child: LinearProgressIndicator(
                backgroundColor: context.theme.colors.muted,
                valueColor: AlwaysStoppedAnimation<Color>(
                  context.theme.colors.primary,
                ),
                minHeight: 4.0,
              ),
            ),
            const Gap(12),
            Text(
              Strings.pleaseWaitSync,
              style: context.theme.typography.sm.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
        actions: const [],
      );
    }
  }
}
