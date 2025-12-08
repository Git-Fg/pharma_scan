import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/providers/theme_provider.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/database_stats_provider.dart';
import 'package:pharma_scan/features/home/providers/sync_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

@RoutePage()
class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeController = useState<ThemeSetting?>(null);
    final frequencyController = useState<UpdateFrequency?>(null);

    final themeState = ref.watch(themeProvider);
    final frequencyState = ref.watch(appPreferencesProvider);
    final hapticSettingsState = ref.watch(hapticSettingsProvider);
    final sortingState = ref.watch(sortingPreferenceProvider);
    final databaseStats = ref.watch(databaseStatsProvider);
    final lastSync = ref.watch(lastSyncEpochStreamProvider);
    final lastSyncEpoch = lastSync.asData?.value;
    final syncDate = lastSyncEpoch != null
        ? DateTime.fromMillisecondsSinceEpoch(lastSyncEpoch)
        : null;
    final ageDays = syncDate != null
        ? DateTime.now().difference(syncDate).inDays
        : null;
    final (Color indicatorColor, String indicatorLabel) = switch (ageDays) {
      null => (
        context.shadColors.destructive,
        Strings.dataUnknown,
      ),
      >= 31 => (
        Colors.orange,
        Strings.dataStaleWarning,
      ),
      _ => (
        context.shadColors.primary,
        syncDate != null
            ? '${Strings.dataFresh} ${_formatDate(syncDate)}'
            : Strings.dataFresh,
      ),
    };
    final isFrequencyLoading = frequencyState.isLoading;
    final isResetting = useState(false);
    final isCheckingUpdates = useState(false);

    void showDestructiveErrorToast(Object error) {
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text(Strings.error),
          description: Text(error.toString()),
        ),
      );
    }

    ref
      ..listen(themeMutationProvider, (prev, next) {
        next.whenOrNull(
          error: (error, _) => showDestructiveErrorToast(error),
        );
      })
      ..listen(updateFrequencyMutationProvider, (prev, next) {
        next.whenOrNull(
          error: (Object error, _) => showDestructiveErrorToast(error),
        );
      })
      ..listen(hapticMutationProvider, (prev, next) {
        next.whenOrNull(
          error: (Object error, _) => showDestructiveErrorToast(error),
        );
      })
      ..listen(sortingPreferenceMutationProvider, (prev, next) {
        next.whenOrNull(
          error: (Object error, _) => showDestructiveErrorToast(error),
        );
      });

    final themeModeValue = themeState.maybeWhen(
      data: (mode) => mode,
      orElse: () => null,
    );
    final selectedFrequency = frequencyState.maybeWhen(
      data: (freq) => freq,
      orElse: () => null,
    );
    final hapticEnabled = hapticSettingsState.maybeWhen(
      data: (enabled) => enabled,
      orElse: () => true,
    );
    final sortingPreference = sortingState.maybeWhen<SortingPreference>(
      data: (SortingPreference pref) => pref,
      orElse: () => SortingPreference.princeps,
    );

    useEffect(() {
      if (themeModeValue != null) {
        themeController.value = themeSettingFromThemeMode(themeModeValue);
      }
      return null;
    }, [themeModeValue]);

    useEffect(() {
      if (selectedFrequency != null) {
        frequencyController.value = selectedFrequency;
      }
      return null;
    }, [selectedFrequency]);

    Future<void> performReset() async {
      Navigator.of(context).pop();
      isResetting.value = true;

      try {
        await ref
            .read(dataInitializationServiceProvider)
            .initializeDatabase(forceRefresh: true);

        if (context.mounted) {
          ShadToaster.of(context).show(
            const ShadToast(
              title: Text(Strings.resetComplete),
              description: Text(Strings.resetSuccess),
            ),
          );
        }
      } on Exception catch (_) {
        if (context.mounted) {
          ShadToaster.of(context).show(
            const ShadToast.destructive(
              title: Text(Strings.resetError),
              description: Text(Strings.resetErrorDescription),
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
      unawaited(
        showShadSheet<void>(
          context: context,
          side: ShadSheetSide.bottom,
          builder: (overlayContext) {
            return ShadSheet(
              title: const Text(Strings.resetDatabaseTitle),
              description: const Text(Strings.resetDatabaseDescription),
              actions: [
                Semantics(
                  button: true,
                  label: Strings.cancelButtonLabel,
                  hint: Strings.cancelButtonHint,
                  child: ShadButton.outline(
                    onPressed: () => Navigator.of(overlayContext).pop(),
                    child: const Text(Strings.cancel),
                  ),
                ),
                Semantics(
                  button: true,
                  label: Strings.confirmButtonLabel,
                  hint: Strings.confirmResetButtonHint,
                  child: ShadButton(
                    onPressed: () {
                      Navigator.of(overlayContext).pop();
                      unawaited(performReset());
                    },
                    child: const Text(Strings.confirm),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    Future<void> runManualSync() async {
      if (isCheckingUpdates.value) return;
      isCheckingUpdates.value = true;

      unawaited(
        showShadSheet<void>(
          context: context,
          side: ShadSheetSide.bottom,
          builder: (overlayContext) => const _SyncProgressDialog(),
        ),
      );

      try {
        final updated = await ref
            .read(syncControllerProvider.notifier)
            .startSync(force: true);
        if (!context.mounted) return;
        ShadToaster.of(context).show(
          ShadToast(
            title: Text(updated ? Strings.bdpmSynced : Strings.noNewUpdates),
            description: Text(
              updated
                  ? Strings.latestBdpmDataApplied
                  : Strings.localDataUpToDate,
            ),
          ),
        );
      } on Exception catch (_) {
        if (!context.mounted) return;
        ShadToaster.of(context).show(
          const ShadToast.destructive(
            title: Text(Strings.syncFailed),
            description: Text(Strings.unableToCheckBdpmUpdates),
          ),
        );
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          isCheckingUpdates.value = false;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          Strings.settings,
          style: context.shadTextTheme.h4,
        ),
        leading: ShadIconButton.ghost(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppDimens.spacingSm),
            child: Semantics(
              label: indicatorLabel,
              child: Tooltip(
                message: indicatorLabel,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.shadColors.border,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.spacingMd),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ShadCard(
                      title: const Text(Strings.appearance),
                      description: const Text(Strings.appearanceDescription),
                      child: ShadSelect<ThemeSetting>(
                        key: ValueKey('theme_${themeController.value}'),
                        initialValue: themeController.value,
                        placeholder: const Text(Strings.themeSelectorLabel),
                        selectedOptionBuilder: (context, value) {
                          final (label, icon) = switch (value) {
                            ThemeSetting.system => (
                              Strings.systemTheme,
                              LucideIcons.monitor,
                            ),
                            ThemeSetting.light => (
                              Strings.lightTheme,
                              LucideIcons.sun,
                            ),
                            ThemeSetting.dark => (
                              Strings.darkTheme,
                              LucideIcons.moon,
                            ),
                          };
                          return Row(
                            children: [
                              Icon(icon, size: AppDimens.iconSm),
                              const Gap(AppDimens.spacingSm),
                              Text(label),
                            ],
                          );
                        },
                        onChanged: (value) {
                          if (value != null) {
                            unawaited(
                              ref
                                  .read(themeMutationProvider.notifier)
                                  .setTheme(value),
                            );
                          }
                        },
                        options: const [
                          ShadOption(
                            value: ThemeSetting.system,
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.monitor,
                                  size: AppDimens.iconSm,
                                ),
                                Gap(AppDimens.spacingSm),
                                Text(Strings.systemTheme),
                              ],
                            ),
                          ),
                          ShadOption(
                            value: ThemeSetting.light,
                            child: Row(
                              children: [
                                Icon(LucideIcons.sun, size: AppDimens.iconSm),
                                Gap(AppDimens.spacingSm),
                                Text(Strings.lightTheme),
                              ],
                            ),
                          ),
                          ShadOption(
                            value: ThemeSetting.dark,
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.moon,
                                  size: AppDimens.iconSm,
                                ),
                                Gap(AppDimens.spacingSm),
                                Text(Strings.darkTheme),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(AppDimens.spacingMd),
                    ShadCard(
                      title: const Text(Strings.hapticsTitle),
                      description: const Text(Strings.hapticsDescription),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                LucideIcons.vibrate,
                                size: AppDimens.iconSm,
                              ),
                              Gap(AppDimens.spacingSm),
                              Text(Strings.hapticsVibrationsLabel),
                            ],
                          ),
                          ShadSwitch(
                            value: hapticEnabled,
                            onChanged: (value) {
                              unawaited(
                                ref
                                    .read(hapticMutationProvider.notifier)
                                    .setEnabled(enabled: value),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Gap(AppDimens.spacingMd),
                    ShadCard(
                      title: const Text(Strings.sortingTitle),
                      description: const Text(Strings.sortingDescription),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                LucideIcons.arrowUpDown,
                                size: AppDimens.iconSm,
                              ),
                              Gap(AppDimens.spacingSm),
                              Text(Strings.sortingDescription),
                            ],
                          ),
                          ShadSelect<SortingPreference>(
                            key: ValueKey('sorting_$sortingPreference'),
                            initialValue: sortingPreference,
                            placeholder: const Text(Strings.sortingTitle),
                            selectedOptionBuilder: (context, value) {
                              final label = switch (value) {
                                SortingPreference.generic =>
                                  Strings.sortingByName,
                                SortingPreference.princeps =>
                                  Strings.sortingByPrinceps,
                              };
                              return Text(label);
                            },
                            onChanged: (value) {
                              if (value != null) {
                                unawaited(
                                  ref
                                      .read(
                                        sortingPreferenceMutationProvider
                                            .notifier,
                                      )
                                      .setSortingPreference(value),
                                );
                              }
                            },
                            options: const [
                              ShadOption(
                                value: SortingPreference.princeps,
                                child: Text(Strings.sortingByPrinceps),
                              ),
                              ShadOption(
                                value: SortingPreference.generic,
                                child: Text(Strings.sortingByName),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Gap(AppDimens.spacingMd),
                    ShadCard(
                      title: const Text(Strings.sync),
                      description: const Text(Strings.determinesCheckFrequency),
                      child: ShadSelect<UpdateFrequency>(
                        key: ValueKey('frequency_$selectedFrequency'),
                        initialValue: selectedFrequency,
                        placeholder: const Text(Strings.syncFrequencyLabel),
                        enabled: !isFrequencyLoading,
                        selectedOptionBuilder: (context, value) {
                          final (label, icon) = switch (value) {
                            UpdateFrequency.none => (
                              Strings.never,
                              LucideIcons.ban,
                            ),
                            UpdateFrequency.daily => (
                              Strings.daily,
                              LucideIcons.calendarDays,
                            ),
                            UpdateFrequency.weekly => (
                              Strings.weekly,
                              LucideIcons.calendarRange,
                            ),
                            UpdateFrequency.monthly => (
                              Strings.monthly,
                              LucideIcons.calendar,
                            ),
                          };
                          return Row(
                            children: [
                              Icon(icon, size: AppDimens.iconSm),
                              const Gap(AppDimens.spacingSm),
                              Text(label),
                            ],
                          );
                        },
                        onChanged: (value) {
                          if (value != null) {
                            unawaited(
                              ref
                                  .read(
                                    updateFrequencyMutationProvider.notifier,
                                  )
                                  .setUpdateFrequency(value),
                            );
                          }
                        },
                        options: const [
                          ShadOption(
                            value: UpdateFrequency.none,
                            child: Row(
                              children: [
                                Icon(LucideIcons.ban, size: AppDimens.iconSm),
                                Gap(AppDimens.spacingSm),
                                Text(Strings.never),
                              ],
                            ),
                          ),
                          ShadOption(
                            value: UpdateFrequency.daily,
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.calendarDays,
                                  size: AppDimens.iconSm,
                                ),
                                Gap(AppDimens.spacingSm),
                                Text(Strings.daily),
                              ],
                            ),
                          ),
                          ShadOption(
                            value: UpdateFrequency.weekly,
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.calendarRange,
                                  size: AppDimens.iconSm,
                                ),
                                Gap(AppDimens.spacingSm),
                                Text(Strings.weekly),
                              ],
                            ),
                          ),
                          ShadOption(
                            value: UpdateFrequency.monthly,
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.calendar,
                                  size: AppDimens.iconSm,
                                ),
                                Gap(AppDimens.spacingSm),
                                Text(Strings.monthly),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(AppDimens.spacingMd),
                    ShadCard(
                      title: const Text(Strings.data),
                      description: const Text(Strings.dataSectionDescription),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ShadButton.outline(
                            width: double.infinity,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            leading: isCheckingUpdates.value
                                ? const SizedBox(
                                    width: AppDimens.iconSm,
                                    height: AppDimens.iconSm,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(LucideIcons.refreshCw),
                            onPressed: isCheckingUpdates.value
                                ? null
                                : runManualSync,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isCheckingUpdates.value
                                      ? Strings.checkingUpdatesInProgress
                                      : Strings.checkUpdatesNow,
                                ),
                                const Gap(4),
                                Text(
                                  isCheckingUpdates.value
                                      ? Strings.pleaseWaitSync
                                      : Strings.checkUpdatesTitle,
                                  style: context.shadTextTheme.small,
                                ),
                              ],
                            ),
                          ),
                          const Gap(AppDimens.spacingSm),
                          ShadButton.outline(
                            width: double.infinity,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            leading: const Icon(LucideIcons.databaseZap),
                            onPressed: showResetConfirmation,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(Strings.forceReset),
                                const Gap(4),
                                Text(
                                  Strings.forceResetDescription,
                                  style: context.shadTextTheme.small,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(AppDimens.spacingMd),
                    ShadCard(
                      title: const Text(Strings.diagnostics),
                      description: const Text(Strings.diagnosticsDescription),
                      child: ShadButton.outline(
                        width: double.infinity,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        leading: const Icon(LucideIcons.terminal),
                        onPressed: () =>
                            AutoRouter.of(context).push(const LogsRoute()),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(Strings.showLogs),
                            const Gap(4),
                            Text(
                              Strings.openDetailedViewForSupport,
                              style: context.shadTextTheme.small,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Gap(AppDimens.spacingMd),
                    databaseStats.when(
                      data: (stats) => ShadCard(
                        title: const Text(Strings.databaseStatsTitle),
                        description: const Text(
                          Strings.databaseStatsDescription,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppDimens.spacingXs,
                            horizontal: AppDimens.spacingSm,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatsItem(
                                icon: LucideIcons.star,
                                label: Strings.totalPrinceps,
                                value: '${stats.totalPrinceps}',
                              ),
                              _StatsItem(
                                icon: LucideIcons.pill,
                                label: Strings.totalGenerics,
                                value: '${stats.totalGeneriques}',
                              ),
                              _StatsItem(
                                icon: LucideIcons.activity,
                                label: Strings.totalPrinciples,
                                value: '${stats.totalPrincipes}',
                              ),
                            ],
                          ),
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (error, _) => const SizedBox.shrink(),
                    ),
                    const Gap(AppDimens.spacingXl),
                  ],
                ),
              ),
            ),
          ),
          if (isResetting.value)
            Positioned.fill(
              child: ColoredBox(
                color: ShadTheme.of(
                  context,
                ).colorScheme.background.withValues(alpha: 0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        height: 4,
                        child: ShadProgress(),
                      ),
                      const Gap(AppDimens.spacingMd),
                      Text(
                        Strings.resetting,
                        style: context.shadTextTheme.p,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _formatDate(DateTime date) =>
    '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year}';

class _SyncProgressDialog extends StatelessWidget {
  const _SyncProgressDialog();

  @override
  Widget build(BuildContext context) {
    return const ShadSheet(
      title: Text(Strings.checkUpdates),
      description: Text(Strings.pleaseWaitSync),
      child: SizedBox(
        height: 4,
        child: ShadProgress(),
      ),
    );
  }
}

class _StatsItem extends StatelessWidget {
  const _StatsItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(
            icon,
            size: AppDimens.iconSm,
            color: theme.colorScheme.primary,
          ),
        ),
        const Gap(AppDimens.spacing2xs),
        Text(
          value,
          style: theme.textTheme.h4.copyWith(fontWeight: FontWeight.bold),
        ),
        const Gap(AppDimens.spacing2xs),
        Text(
          label,
          style: theme.textTheme.small.copyWith(
            color: theme.colorScheme.mutedForeground,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
