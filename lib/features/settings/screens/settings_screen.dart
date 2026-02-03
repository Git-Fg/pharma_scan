import 'dart:async' show unawaited;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/providers/theme_provider.dart';
import 'package:pharma_scan/app/router/app_router.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/providers/database_stats_provider.dart';
import 'package:pharma_scan/core/providers/sync_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pharma_scan/core/widgets/update_dialog.dart';

@RoutePage()
class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeController = useState<ThemeSetting?>(null);
    final frequencyController = useState<UpdateFrequency?>(null);
    final policyController = useState<String?>(null);

    final themeState = ref.watch(themeProvider);
    final frequencyState = ref.watch(appPreferencesProvider);
    final policyState = ref.watch(activeUpdatePolicyProvider);
    final packageInfoSnapshot = useFuture(
      useMemoized(PackageInfo.fromPlatform),
    );
    final packageInfo = packageInfoSnapshot.data;

    final hapticSettingsState = ref.watch(hapticSettingsProvider);
    final sortingState = ref.watch(sortingPreferenceProvider);
    final databaseStats = ref.watch(databaseStatsProvider);
    final lastSyncEpochAsync = ref.watch(lastSyncEpochProvider);
    final lastSyncEpoch = lastSyncEpochAsync.value;
    final syncDate = lastSyncEpoch != null
        ? DateTime.fromMillisecondsSinceEpoch(lastSyncEpoch)
        : null;
    final ageDays = syncDate != null
        ? DateTime.now().difference(syncDate).inDays
        : null;
    final (Color indicatorColor, String indicatorLabel) = switch (ageDays) {
      null => (context.colors.destructive, Strings.dataUnknown),
      >= 31 => (context.colors.destructive, Strings.dataStaleWarning),
      _ => (
        context.colors.primary,
        syncDate != null
            ? '${Strings.dataFresh} ${_formatDate(syncDate)}'
            : Strings.dataFresh,
      ),
    };

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
        next.whenOrNull(error: (error, _) => showDestructiveErrorToast(error));
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
      })
      ..listen(updatePolicyMutationProvider, (prev, next) {
        next.whenOrNull(
          error: (Object error, _) => showDestructiveErrorToast(error),
        );
      });

    final themeModeValue = themeState;
    final selectedFrequency = frequencyState.value;
    final hapticEnabled = hapticSettingsState.value ?? true;
    final sortingPreference = sortingState.value;
    final updatePolicyValue = policyState.value;

    useEffect(() {
      themeController.value = themeSettingFromThemeMode(themeModeValue);
      return null;
    }, [themeModeValue]);

    useEffect(() {
      frequencyController.value = selectedFrequency;
      return null;
    }, [selectedFrequency]);

    useEffect(() {
      policyController.value = updatePolicyValue;
      return null;
    }, [updatePolicyValue]);

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
          side: .bottom,
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
          side: .bottom,
          builder: (overlayContext) => const _SyncProgressDialog(),
        ),
      );

      try {
        final result = await ref
            .read(dataInitializationServiceProvider)
            .checkVersionStatus(ignorePolicy: true);

        if (!context.mounted) return;

        if (result?.updateAvailable == true) {
          final shouldUpdate = await showDialog<bool>(
            context: context,
            builder: (context) => UpdateDialog(versionResult: result!),
          );

          if (shouldUpdate == true && context.mounted) {
            final updated = await ref
                .read(syncControllerProvider.notifier)
                .startSync(force: true);

            if (!context.mounted) return;
            ShadToaster.of(context).show(
              ShadToast(
                title: Text(
                  updated ? Strings.bdpmSynced : Strings.noNewUpdates,
                ),
                description: Text(
                  updated
                      ? Strings.latestBdpmDataApplied
                      : Strings.localDataUpToDate,
                ),
              ),
            );
          }
        } else {
          ShadToaster.of(context).show(
            const ShadToast(
              title: Text(Strings.noNewUpdates),
              description: Text(Strings.localDataUpToDate),
            ),
          );
        }
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

    final surfaceTint = context.colors.primary.withValues(alpha: 0.02);

    return Scaffold(
      backgroundColor: Color.alphaBlend(surfaceTint, context.colors.background),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: AutoLeadingButton(color: context.colors.foreground),
        title: Text(Strings.settings, style: context.typo.h3),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Semantics(
              label: indicatorLabel,
              child: Tooltip(
                message: indicatorLabel,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: indicatorColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: indicatorColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: LayoutBreakpoints.desktop,
                        ),
                        child: Column(
                          crossAxisAlignment: .stretch,
                          children: [
                            ShadCard(
                              title: const Text(Strings.appearance),
                              description: const Text(
                                Strings.appearanceDescription,
                              ),
                              child: ShadSelect<ThemeSetting>(
                                key: ValueKey('theme_${themeController.value}'),
                                initialValue: themeController.value,
                                placeholder: const Text(
                                  Strings.themeSelectorLabel,
                                ),
                                selectedOptionBuilder: (context, value) {
                                  final (label, icon) = switch (value) {
                                    .system => (
                                      Strings.systemTheme,
                                      LucideIcons.monitor,
                                    ),
                                    .light => (
                                      Strings.lightTheme,
                                      LucideIcons.sun,
                                    ),
                                    .dark => (
                                      Strings.darkTheme,
                                      LucideIcons.moon,
                                    ),
                                  };
                                  return Row(
                                    children: [
                                      Icon(icon, size: 16),
                                      const Gap(12),
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
                                  ShadOption<ThemeSetting>(
                                    value: .system,
                                    child: Row(
                                      children: [
                                        Icon(LucideIcons.monitor, size: 16),
                                        Gap(12),
                                        Text(Strings.systemTheme),
                                      ],
                                    ),
                                  ),
                                  ShadOption<ThemeSetting>(
                                    value: .light,
                                    child: Row(
                                      children: [
                                        Icon(LucideIcons.sun, size: 16),
                                        Gap(12),
                                        Text(Strings.lightTheme),
                                      ],
                                    ),
                                  ),
                                  ShadOption<ThemeSetting>(
                                    value: .dark,
                                    child: Row(
                                      children: [
                                        Icon(LucideIcons.moon, size: 16),
                                        Gap(12),
                                        Text(Strings.darkTheme),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Gap(20),
                            ShadCard(
                              title: const Text(Strings.hapticsTitle),
                              description: const Text(
                                Strings.hapticsDescription,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(
                                          LucideIcons.vibrate,
                                          size: 16,
                                        ),
                                        const Gap(12),
                                        Flexible(
                                          child: Text(
                                            Strings.hapticsVibrationsLabel,
                                            style: context.typo.p.copyWith(
                                              color: context.colors.foreground,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ShadSwitch(
                                    value: hapticEnabled,
                                    onChanged: (value) => unawaited(
                                      ref
                                          .read(hapticMutationProvider.notifier)
                                          .setEnabled(enabled: value),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Gap(20),
                            ShadCard(
                              title: const Text(Strings.sortingTitle),
                              description: const Text(
                                Strings.sortingDescription,
                              ),
                              child: ShadSelect<SortingPreference>(
                                key: ValueKey('sorting_$sortingPreference'),
                                initialValue: sortingPreference,
                                placeholder: const Text(Strings.sortingTitle),
                                selectedOptionBuilder: (context, value) {
                                  final label = switch (value) {
                                    SortingPreference.generic =>
                                      Strings.sortingByName,
                                    SortingPreference.princeps =>
                                      Strings.sortingByPrinceps,
                                    SortingPreference.form =>
                                      Strings.sortingByForm,
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
                                  ShadOption<SortingPreference>(
                                    value: SortingPreference.princeps,
                                    child: Text(Strings.sortingByPrinceps),
                                  ),
                                  ShadOption<SortingPreference>(
                                    value: SortingPreference.generic,
                                    child: Text(Strings.sortingByName),
                                  ),
                                  ShadOption<SortingPreference>(
                                    value: SortingPreference.form,
                                    child: Text(Strings.sortingByForm),
                                  ),
                                ],
                              ),
                            ),
                            const Gap(20),
                            ShadCard(
                              title: const Text(
                                'Mises à jour de la base de données',
                              ),
                              description: const Text(
                                'Configurez le comportement des mises à jour.',
                              ),
                              child: Column(
                                crossAxisAlignment: .stretch,
                                children: [
                                  ShadSelect<String>(
                                    key: ValueKey(
                                      'policy_${policyController.value}',
                                    ),
                                    initialValue: policyController.value,
                                    placeholder: const Text('Comportement'),
                                    selectedOptionBuilder: (context, value) {
                                      final label = switch (value) {
                                        'always' => 'Toujours mettre à jour',
                                        'never' => 'Ne jamais demander',
                                        _ => 'Demander à chaque fois',
                                      };
                                      return Text(label);
                                    },
                                    onChanged: (value) {
                                      if (value != null) {
                                        unawaited(
                                          ref
                                              .read(
                                                updatePolicyMutationProvider
                                                    .notifier,
                                              )
                                              .setPolicy(value),
                                        );
                                      }
                                    },
                                    options: const [
                                      ShadOption(
                                        value: 'ask',
                                        child: Text('Demander à chaque fois'),
                                      ),
                                      ShadOption(
                                        value: 'always',
                                        child: Text('Toujours mettre à jour'),
                                      ),
                                      ShadOption(
                                        value: 'never',
                                        child: Text('Ne jamais demander'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Gap(20),
                            ShadCard(
                              title: const Text(Strings.sync),
                              description: const Text(
                                Strings.determinesCheckFrequency,
                              ),
                              child: ShadSelect<UpdateFrequency>(
                                key: ValueKey('frequency_$selectedFrequency'),
                                initialValue: selectedFrequency,
                                placeholder: const Text(
                                  Strings.syncFrequencyLabel,
                                ),
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
                                      Icon(icon, size: 16),
                                      Gap(context.spacing.sm),
                                      Text(label),
                                    ],
                                  );
                                },
                                onChanged: (value) {
                                  if (value != null) {
                                    unawaited(
                                      ref
                                          .read(
                                            updateFrequencyMutationProvider
                                                .notifier,
                                          )
                                          .setUpdateFrequency(value),
                                    );
                                  }
                                },
                                options: const [
                                  ShadOption<UpdateFrequency>(
                                    value: UpdateFrequency.none,
                                    child: Row(
                                      children: [
                                        Icon(LucideIcons.ban, size: 16),
                                        Gap(12),
                                        Text(Strings.never),
                                      ],
                                    ),
                                  ),
                                  ShadOption<UpdateFrequency>(
                                    value: UpdateFrequency.daily,
                                    child: Row(
                                      children: [
                                        Icon(
                                          LucideIcons.calendarDays,
                                          size: 16,
                                        ),
                                        Gap(12),
                                        Text(Strings.daily),
                                      ],
                                    ),
                                  ),
                                  ShadOption<UpdateFrequency>(
                                    value: UpdateFrequency.weekly,
                                    child: Row(
                                      children: [
                                        Icon(
                                          LucideIcons.calendarRange,
                                          size: 16,
                                        ),
                                        Gap(12),
                                        Text(Strings.weekly),
                                      ],
                                    ),
                                  ),
                                  ShadOption<UpdateFrequency>(
                                    value: UpdateFrequency.monthly,
                                    child: Row(
                                      children: [
                                        Icon(LucideIcons.calendar, size: 16),
                                        Gap(12),
                                        Text(Strings.monthly),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Gap(24),
                            ShadCard(
                              title: const Text(Strings.data),
                              description: const Text(
                                Strings.dataSectionDescription,
                              ),
                              child: Column(
                                crossAxisAlignment: .stretch,
                                children: [
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 72,
                                    ),
                                    child: ShadButton.outline(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      mainAxisAlignment: .start,
                                      leading: isCheckingUpdates.value
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(LucideIcons.refreshCw),
                                      onPressed: isCheckingUpdates.value
                                          ? null
                                          : runManualSync,
                                      child: Expanded(
                                        child: Column(
                                          crossAxisAlignment: .start,
                                          mainAxisSize: .min,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                isCheckingUpdates.value
                                                    ? Strings
                                                          .checkingUpdatesInProgress
                                                    : Strings.checkUpdatesNow,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const Gap(4),
                                            Flexible(
                                              child: Text(
                                                isCheckingUpdates.value
                                                    ? Strings.pleaseWaitSync
                                                    : Strings.checkUpdatesTitle,
                                                style: context.typo.small,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Gap(12),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: 72,
                                    ),
                                    child: ShadButton.outline(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      mainAxisAlignment: .start,
                                      leading: const Icon(
                                        LucideIcons.databaseZap,
                                      ),
                                      onPressed: showResetConfirmation,
                                      child: Expanded(
                                        child: Column(
                                          crossAxisAlignment: .start,
                                          mainAxisSize: .min,
                                          children: [
                                            const Flexible(
                                              child: Text(
                                                Strings.forceReset,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const Gap(4),
                                            Flexible(
                                              child: Text(
                                                Strings.forceResetDescription,
                                                style: context.typo.small,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Gap(20),
                            ShadCard(
                              title: const Text(Strings.diagnostics),
                              description: const Text(
                                Strings.diagnosticsDescription,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 72,
                                ),
                                child: ShadButton.outline(
                                  width: double.infinity,
                                  padding: const .symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  mainAxisAlignment: .start,
                                  leading: const Icon(LucideIcons.terminal),
                                  onPressed: () => AutoRouter.of(
                                    context,
                                  ).push(const LogsRoute()),
                                  child: Expanded(
                                    child: Column(
                                      crossAxisAlignment: .start,
                                      mainAxisSize: .min,
                                      children: [
                                        const Text(Strings.showLogs),
                                        const Gap(4),
                                        Text(
                                          Strings.openDetailedViewForSupport,
                                          style: context.typo.small,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const Gap(20),
                            databaseStats.when(
                              data: (stats) => ShadCard(
                                title: const Text(Strings.databaseStatsTitle),
                                description: const Text(
                                  Strings.databaseStatsDescription,
                                ),
                                child: Padding(
                                  padding: const .symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: .spaceAround,
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
                            const Gap(20),
                            if (packageInfo != null)
                              ShadCard(
                                title: const Text(Strings.appInfo),
                                description: const Text(
                                  Strings.appInfoDescription,
                                ),
                                child: Column(
                                  children: [
                                    _AppInfoItem(
                                      label: Strings.version,
                                      value: packageInfo.version,
                                    ),
                                    const Gap(12),
                                    _AppInfoItem(
                                      label: Strings.buildNumber,
                                      value: packageInfo.buildNumber,
                                    ),
                                    const Gap(12),
                                    _AppInfoItem(
                                      label: Strings.packageName,
                                      value: packageInfo.packageName,
                                    ),
                                  ],
                                ),
                              ),
                            const Gap(24),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
          if (isResetting.value)
            Positioned.fill(
              child: ColoredBox(
                color: context.colors.background.withValues(alpha: 0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: .min,
                    children: [
                      SizedBox(
                        height: 4,
                        child: ClipRRect(
                          borderRadius: .circular(999),
                          child: LinearProgressIndicator(
                            backgroundColor: context.colors.mutedForeground
                                .withValues(alpha: 0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              context.colors.primary,
                            ),
                          ),
                        ),
                      ),
                      const Gap(16),
                      Text(Strings.resetting, style: context.typo.p),
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
    final colors = context.colors;
    return ShadSheet(
      title: const Text(Strings.checkUpdates),
      description: const Text(Strings.pleaseWaitSync),
      child: SizedBox(
        height: 4,
        child: ClipRRect(
          borderRadius: .circular(999),
          child: LinearProgressIndicator(
            backgroundColor: colors.mutedForeground.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
          ),
        ),
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
      mainAxisSize: .min,
      children: [
        ExcludeSemantics(
          child: Icon(icon, size: 16, color: theme.colorScheme.primary),
        ),
        const Gap(4),
        Text(
          value,
          style: theme.textTheme.h4.copyWith(fontWeight: FontWeight.bold),
        ),
        const Gap(4),
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

class _AppInfoItem extends StatelessWidget {
  const _AppInfoItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: .spaceBetween,
      crossAxisAlignment: .start,
      children: [
        Flexible(
          child: Text(
            label,
            style: context.typo.muted,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Gap(12),
        Flexible(
          child: Text(
            value,
            style: context.typo.small,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
