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
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/section_header.dart';
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
    final isFrequencyLoading = frequencyState.isLoading;
    final isResetting = useState(false);
    final isCheckingUpdates = useState(false);

    final themeModeValue = themeState.maybeWhen(
      data: (mode) => mode,
      orElse: () => null,
    );
    final selectedFrequency = frequencyState.maybeWhen(
      data: (freq) => freq,
      orElse: () => null,
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
          style: ShadTheme.of(context).textTheme.h4,
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Appearance Section
              const SliverToBoxAdapter(
                child: SectionHeader(
                  title: Strings.appearance,
                  icon: LucideIcons.palette,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingMd,
                ),
                sliver: SliverToBoxAdapter(
                  child: FocusTraversalGroup(
                    child: Semantics(
                      label: Strings.themeSelectorLabel,
                      hint: Strings.selectThemeHint,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppDimens.spacingXs,
                            ),
                            child: Text(
                              Strings.appearanceDescription,
                              style: ShadTheme.of(context).textTheme.muted,
                            ),
                          ),
                          ShadRadioGroup<ThemeSetting>(
                            key: ValueKey('theme_${themeController.value}'),
                            initialValue: themeController.value,
                            onChanged: (value) {
                              if (value != null) {
                                unawaited(
                                  ref
                                      .read(themeProvider.notifier)
                                      .setTheme(value),
                                );
                              }
                            },
                            items: [
                              _buildThemeRadio(
                                context,
                                ThemeSetting.system,
                                Strings.systemTheme,
                                LucideIcons.monitor,
                              ),
                              _buildThemeRadio(
                                context,
                                ThemeSetting.light,
                                Strings.lightTheme,
                                LucideIcons.sun,
                              ),
                              _buildThemeRadio(
                                context,
                                ThemeSetting.dark,
                                Strings.darkTheme,
                                LucideIcons.moon,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Sync Section
              const SliverToBoxAdapter(
                child: SectionHeader(
                  title: Strings.sync,
                  icon: LucideIcons.refreshCw,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingMd,
                ),
                sliver: SliverToBoxAdapter(
                  child: FocusTraversalGroup(
                    child: Semantics(
                      label: Strings.syncFrequencyLabel,
                      hint: Strings.selectSyncFrequencyHint,
                      enabled: !isFrequencyLoading,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppDimens.spacingXs,
                            ),
                            child: Text(
                              Strings.determinesCheckFrequency,
                              style: ShadTheme.of(context).textTheme.muted,
                            ),
                          ),
                          ShadRadioGroup<UpdateFrequency>(
                            key: ValueKey('frequency_$selectedFrequency'),
                            initialValue: selectedFrequency,
                            enabled: !isFrequencyLoading,
                            onChanged: (value) {
                              if (value != null) {
                                unawaited(
                                  ref
                                      .read(appPreferencesProvider.notifier)
                                      .setUpdateFrequency(value),
                                );
                              }
                            },
                            items: [
                              _buildFreqRadio(
                                context,
                                UpdateFrequency.none,
                                Strings.never,
                                LucideIcons.ban,
                              ),
                              _buildFreqRadio(
                                context,
                                UpdateFrequency.daily,
                                Strings.daily,
                                LucideIcons.calendarDays,
                              ),
                              _buildFreqRadio(
                                context,
                                UpdateFrequency.weekly,
                                Strings.weekly,
                                LucideIcons.calendarRange,
                              ),
                              _buildFreqRadio(
                                context,
                                UpdateFrequency.monthly,
                                Strings.monthly,
                                LucideIcons.calendar,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Data Section
              const SliverToBoxAdapter(
                child: SectionHeader(
                  title: Strings.data,
                  icon: LucideIcons.database,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingMd,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AppDimens.spacingMd,
                          bottom: AppDimens.spacingXs,
                        ),
                        child: Text(
                          Strings.dataSectionDescription,
                          style: ShadTheme.of(context).textTheme.small.copyWith(
                            color: ShadTheme.of(
                              context,
                            ).colorScheme.mutedForeground,
                          ),
                        ),
                      ),
                      _buildTile(
                        context: context,
                        prefix: const Icon(LucideIcons.refreshCw),
                        title: isCheckingUpdates.value
                            ? Strings.checkingUpdatesInProgress
                            : Strings.checkUpdatesNow,
                        subtitle: isCheckingUpdates.value
                            ? Strings.pleaseWaitSync
                            : Strings.checkUpdatesTitle,
                        enabled: !isCheckingUpdates.value,
                        onTap: isCheckingUpdates.value ? null : runManualSync,
                        trailing: isCheckingUpdates.value
                            ? const SizedBox(
                                width: AppDimens.iconSm,
                                height: AppDimens.iconSm,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                LucideIcons.chevronRight,
                                size: 16,
                              ),
                      ),
                      ShadSeparator.horizontal(
                        thickness: 1,
                        color: ShadTheme.of(context).colorScheme.border,
                      ),
                      _buildTile(
                        context: context,
                        prefix: const Icon(LucideIcons.databaseZap),
                        title: Strings.forceReset,
                        subtitle: Strings.forceResetDescription,
                        onTap: showResetConfirmation,
                        trailing: const Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Diagnostics Section
              const SliverToBoxAdapter(
                child: SectionHeader(
                  title: Strings.diagnostics,
                  icon: LucideIcons.terminal,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingMd,
                ),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: AppDimens.spacingMd,
                          bottom: AppDimens.spacingXs,
                        ),
                        child: Text(
                          Strings.diagnosticsDescription,
                          style: ShadTheme.of(context).textTheme.small.copyWith(
                            color: ShadTheme.of(
                              context,
                            ).colorScheme.mutedForeground,
                          ),
                        ),
                      ),
                      _buildTile(
                        context: context,
                        prefix: const Icon(LucideIcons.terminal),
                        title: Strings.showLogs,
                        subtitle: Strings.openDetailedViewForSupport,
                        onTap: () => context.router.push(const LogsRoute()),
                        trailing: const Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom spacing
              const SliverToBoxAdapter(child: Gap(AppDimens.spacingXl)),
            ],
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
                        style: ShadTheme.of(context).textTheme.p,
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

  Widget _buildTile({
    required BuildContext context,
    required String title,
    Widget? prefix,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool enabled = true,
  }) {
    final theme = ShadTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingMd,
            vertical: AppDimens.spacingSm,
          ),
          child: Row(
            children: [
              if (prefix != null) ...[
                prefix,
                const SizedBox(width: AppDimens.spacingSm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.p.copyWith(
                        color: enabled
                            ? theme.colorScheme.foreground
                            : theme.colorScheme.mutedForeground,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.small.copyWith(
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppDimens.spacingSm),
                ExcludeSemantics(child: trailing),
              ],
            ],
          ),
        ),
      ),
    );
  }

  ShadRadio<UpdateFrequency> _buildFreqRadio(
    BuildContext context,
    UpdateFrequency value,
    String label,
    IconData icon,
  ) {
    return ShadRadio<UpdateFrequency>(
      value: value,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppDimens.iconSm),
          const SizedBox(width: AppDimens.spacingSm),
          Text(label),
        ],
      ),
    );
  }

  ShadRadio<ThemeSetting> _buildThemeRadio(
    BuildContext context,
    ThemeSetting value,
    String label,
    IconData icon,
  ) {
    return ShadRadio<ThemeSetting>(
      value: value,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppDimens.iconSm),
          const SizedBox(width: AppDimens.spacingSm),
          Text(label),
        ],
      ),
    );
  }
}

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
