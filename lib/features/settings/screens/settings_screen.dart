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
import 'package:pharma_scan/core/utils/adaptive_overlay.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/section_header_delegate.dart';
import 'package:pharma_scan/features/home/providers/sync_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

@RoutePage()
class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeController = useState<Set<ThemeSetting>>(<ThemeSetting>{});
    final frequencyController = useState<Set<UpdateFrequency>>(
      <UpdateFrequency>{},
    );

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
        themeController.value = {themeSettingFromThemeMode(themeModeValue)};
      }
      return null;
    }, [themeModeValue]);

    useEffect(() {
      if (selectedFrequency != null) {
        frequencyController.value = {selectedFrequency};
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
        showAdaptiveSheet<void>(
          context: context,
          builder: (overlayContext) {
            return SingleChildScrollView(
              child: ShadCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spacingXl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Strings.resetDatabaseTitle,
                        style: ShadTheme.of(context).textTheme.h4,
                      ),
                      const Gap(AppDimens.spacingSm),
                      Text(
                        Strings.resetDatabaseDescription,
                        style: ShadTheme.of(context).textTheme.small.copyWith(
                          color: ShadTheme.of(
                            context,
                          ).colorScheme.mutedForeground,
                        ),
                      ),
                      const Gap(AppDimens.spacingXl),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Semantics(
                            button: true,
                            label: Strings.cancelButtonLabel,
                            hint: Strings.cancelButtonHint,
                            child: ShadButton.outline(
                              onPressed: () =>
                                  Navigator.of(overlayContext).pop(),
                              child: const Text(Strings.cancel),
                            ),
                          ),
                          const Gap(AppDimens.spacingXs),
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
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    Future<void> runManualSync() async {
      if (isCheckingUpdates.value) return;
      isCheckingUpdates.value = true;

      unawaited(
        showAdaptiveSheet<void>(
          context: context,
          isDismissible: false,
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
              SliverMainAxisGroup(
                slivers: [
                  SliverPersistentHeader(
                    delegate: SectionHeaderDelegate(
                      title: Strings.appearance,
                      icon: LucideIcons.palette,
                      textScaler: MediaQuery.textScalerOf(context),
                    ),
                    pinned: true,
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
                          child: _buildSelectGroup<ThemeSetting>(
                            context: context,
                            label: Strings.appearance,
                            description: Strings.appearanceDescription,
                            controller: themeController,
                            options: [
                              (
                                value: ThemeSetting.system,
                                icon: LucideIcons.monitor,
                                label: Strings.systemTheme,
                              ),
                              (
                                value: ThemeSetting.light,
                                icon: LucideIcons.sun,
                                label: Strings.lightTheme,
                              ),
                              (
                                value: ThemeSetting.dark,
                                icon: LucideIcons.moon,
                                label: Strings.darkTheme,
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                unawaited(
                                  ref
                                      .read(themeProvider.notifier)
                                      .setTheme(value),
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Sync Section
              SliverMainAxisGroup(
                slivers: [
                  SliverPersistentHeader(
                    delegate: SectionHeaderDelegate(
                      title: Strings.sync,
                      icon: LucideIcons.refreshCw,
                      textScaler: MediaQuery.textScalerOf(context),
                    ),
                    pinned: true,
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
                          child: _buildSelectGroup<UpdateFrequency>(
                            context: context,
                            label: Strings.sync,
                            description: Strings.determinesCheckFrequency,
                            controller: frequencyController,
                            enabled: !isFrequencyLoading,
                            options: [
                              (
                                value: UpdateFrequency.none,
                                icon: LucideIcons.ban,
                                label: Strings.never,
                              ),
                              (
                                value: UpdateFrequency.daily,
                                icon: LucideIcons.calendarDays,
                                label: Strings.daily,
                              ),
                              (
                                value: UpdateFrequency.weekly,
                                icon: LucideIcons.calendarRange,
                                label: Strings.weekly,
                              ),
                              (
                                value: UpdateFrequency.monthly,
                                icon: LucideIcons.calendar,
                                label: Strings.monthly,
                              ),
                            ],
                            onChanged: isFrequencyLoading
                                ? null
                                : (value) async {
                                    if (value != null) {
                                      await ref
                                          .read(appPreferencesProvider.notifier)
                                          .setUpdateFrequency(value);
                                    }
                                  },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Data Section
              SliverMainAxisGroup(
                slivers: [
                  SliverPersistentHeader(
                    delegate: SectionHeaderDelegate(
                      title: Strings.data,
                      icon: LucideIcons.database,
                      textScaler: MediaQuery.textScalerOf(context),
                    ),
                    pinned: true,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  Strings.data,
                                  style: ShadTheme.of(context).textTheme.h4,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  Strings.dataSectionDescription,
                                  style: ShadTheme.of(context).textTheme.small
                                      .copyWith(
                                        color: ShadTheme.of(
                                          context,
                                        ).colorScheme.mutedForeground,
                                      ),
                                ),
                              ],
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
                            onTap: isCheckingUpdates.value
                                ? null
                                : runManualSync,
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
                          Divider(
                            height: 1,
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
                ],
              ),
              // Diagnostics Section
              SliverMainAxisGroup(
                slivers: [
                  SliverPersistentHeader(
                    delegate: SectionHeaderDelegate(
                      title: Strings.diagnostics,
                      icon: LucideIcons.terminal,
                      textScaler: MediaQuery.textScalerOf(context),
                    ),
                    pinned: true,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  Strings.diagnostics,
                                  style: ShadTheme.of(context).textTheme.h4,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  Strings.diagnosticsDescription,
                                  style: ShadTheme.of(context).textTheme.small
                                      .copyWith(
                                        color: ShadTheme.of(
                                          context,
                                        ).colorScheme.mutedForeground,
                                      ),
                                ),
                              ],
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
                ],
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
                      SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(
                          backgroundColor: ShadTheme.of(
                            context,
                          ).colorScheme.muted,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            ShadTheme.of(context).colorScheme.primary,
                          ),
                          minHeight: 4,
                        ),
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

  Widget _buildSelectGroup<T>({
    required BuildContext context,
    required String label,
    required ValueNotifier<Set<T>> controller,
    required List<({T value, IconData icon, String label})> options,
    required void Function(T?)? onChanged,
    String? description,
    bool enabled = true,
  }) {
    final theme = ShadTheme.of(context);
    final selectedValue = controller.value.isNotEmpty
        ? controller.value.first
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimens.spacingMd,
            bottom: AppDimens.spacingXs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: theme.textTheme.h4),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
        ...options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isSelected = selectedValue == option.value;
          return Column(
            children: [
              InkWell(
                onTap: enabled
                    ? () {
                        controller.value = {option.value};
                        onChanged?.call(option.value);
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spacingMd,
                    vertical: AppDimens.spacingSm,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : null,
                    border: Border(
                      bottom: BorderSide(color: theme.colorScheme.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(option.icon, size: AppDimens.iconSm),
                      const SizedBox(width: AppDimens.spacingSm),
                      Expanded(
                        child: Text(option.label, style: theme.textTheme.p),
                      ),
                      if (isSelected)
                        Icon(
                          LucideIcons.check,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
              if (index < options.length - 1)
                Divider(height: 1, color: theme.colorScheme.border),
            ],
          );
        }),
      ],
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
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spacingMd,
          vertical: AppDimens.spacingSm,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppDimens.spacingXs),
              ExcludeSemantics(child: trailing),
            ],
          ],
        ),
      ),
    );
  }
}

class _SyncProgressDialog extends StatelessWidget {
  const _SyncProgressDialog();

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Strings.checkUpdates,
              style: ShadTheme.of(context).textTheme.h4,
            ),
            const Gap(AppDimens.spacingMd),
            SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                backgroundColor: ShadTheme.of(context).colorScheme.muted,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ShadTheme.of(context).colorScheme.primary,
                ),
                minHeight: 4,
              ),
            ),
            const Gap(12),
            Text(
              Strings.pleaseWaitSync,
              style: ShadTheme.of(context).textTheme.small.copyWith(
                color: ShadTheme.of(context).colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
