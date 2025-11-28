import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

import 'package:forui/forui.dart';
import 'package:forui_hooks/forui_hooks.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
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
    final themeController = useFSelectGroupController<ThemeSetting>();
    final frequencyController = useFSelectGroupController<UpdateFrequency>();

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
    }, [themeModeValue, themeController]);

    useEffect(() {
      if (selectedFrequency != null) {
        frequencyController.value = {selectedFrequency};
      }
      return null;
    }, [selectedFrequency, frequencyController]);

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
      final breakpoints = context.theme.breakpoints;
      final isMobile = MediaQuery.sizeOf(context).width < breakpoints.sm;

      if (isMobile) {
        // Mobile : BottomSheet
        showAdaptiveOverlay<void>(
          context: context,
          builder: (overlayContext) {
            return FCard.raw(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spacingXl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Strings.resetDatabaseTitle,
                      style: context.theme.typography.xl2, // h4 equivalent
                    ),
                    const Gap(AppDimens.spacingSm),
                    Text(
                      Strings.resetDatabaseDescription,
                      style: context.theme.typography.sm.copyWith(
                        color: context.theme.colors.mutedForeground,
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
                          child: FButton(
                            style: FButtonStyle.outline(),
                            onPress: () => Navigator.of(overlayContext).pop(),
                            child: const Text(Strings.cancel),
                          ),
                        ),
                        const Gap(AppDimens.spacingXs),
                        Semantics(
                          button: true,
                          label: Strings.confirmButtonLabel,
                          hint: Strings.confirmResetButtonHint,
                          child: FButton(
                            style: FButtonStyle.primary(),
                            onPress: () {
                              Navigator.of(overlayContext).pop();
                              performReset();
                            },
                            child: const Text(Strings.confirm),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        // Desktop : Dialog using showFDialog directly
        showFDialog<void>(
          context: context,
          builder: (dialogContext, style, animation) {
            return FDialog(
              style: style.call,
              animation: animation,
              title: Text(
                Strings.resetDatabaseTitle,
                style: context.theme.typography.xl2,
              ),
              body: Text(
                Strings.resetDatabaseDescription,
                style: context.theme.typography.base,
              ),
              actions: [
                Semantics(
                  button: true,
                  label: Strings.cancelButtonLabel,
                  hint: Strings.cancelButtonHint,
                  child: FButton(
                    style: FButtonStyle.outline(),
                    onPress: () => Navigator.of(dialogContext).pop(),
                    child: const Text(Strings.cancel),
                  ),
                ),
                Semantics(
                  button: true,
                  label: Strings.confirmButtonLabel,
                  hint: Strings.confirmResetButtonHint,
                  child: FButton(
                    style: FButtonStyle.primary(),
                    onPress: () {
                      Navigator.of(dialogContext).pop();
                      performReset();
                    },
                    child: const Text(Strings.confirm),
                  ),
                ),
              ],
            );
          },
        );
      }
    }

    Future<void> runManualSync() async {
      if (isCheckingUpdates.value) return;
      isCheckingUpdates.value = true;

      unawaited(
        showAdaptiveOverlay<void>(
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
          ListView(
            padding: const EdgeInsets.all(AppDimens.spacingMd),
            children: [
              FocusTraversalGroup(
                child: Semantics(
                  label: Strings.themeSelectorLabel,
                  hint: Strings.selectThemeHint,
                  child: FSelectTileGroup<ThemeSetting>(
                    selectController: themeController,
                    label: const Text(Strings.appearance),
                    description: const Text(Strings.appearanceDescription),
                    divider: FItemDivider.indented,
                    onChange: (values) {
                      if (values.isNotEmpty) {
                        ref.read(themeProvider.notifier).setTheme(values.first);
                      }
                    },
                    children: const [
                      FSelectTile.suffix(
                        prefix: Icon(FIcons.monitor),
                        title: Text(Strings.systemTheme),
                        value: ThemeSetting.system,
                      ),
                      FSelectTile.suffix(
                        prefix: Icon(FIcons.sun),
                        title: Text(Strings.lightTheme),
                        value: ThemeSetting.light,
                      ),
                      FSelectTile.suffix(
                        prefix: Icon(FIcons.moon),
                        title: Text(Strings.darkTheme),
                        value: ThemeSetting.dark,
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(AppDimens.spacingXl),
              FocusTraversalGroup(
                child: Semantics(
                  label: Strings.syncFrequencyLabel,
                  hint: Strings.selectSyncFrequencyHint,
                  enabled: !isFrequencyLoading,
                  child: FSelectTileGroup<UpdateFrequency>(
                    selectController: frequencyController,
                    label: const Text(Strings.sync),
                    description: const Text(Strings.determinesCheckFrequency),
                    divider: FItemDivider.indented,
                    enabled: !isFrequencyLoading,
                    onChange: isFrequencyLoading
                        ? null
                        : (values) async {
                            if (values.isEmpty) return;
                            await ref
                                .read(appPreferencesProvider.notifier)
                                .setUpdateFrequency(values.first);
                          },
                    children: const [
                      FSelectTile.suffix(
                        prefix: Icon(FIcons.ban),
                        title: Text(Strings.never),
                        value: UpdateFrequency.none,
                      ),
                      FSelectTile.suffix(
                        prefix: Icon(FIcons.calendarDays),
                        title: Text(Strings.daily),
                        value: UpdateFrequency.daily,
                      ),
                      FSelectTile.suffix(
                        prefix: Icon(FIcons.calendarRange),
                        title: Text(Strings.weekly),
                        value: UpdateFrequency.weekly,
                      ),
                      FSelectTile.suffix(
                        prefix: Icon(FIcons.calendar),
                        title: Text(Strings.monthly),
                        value: UpdateFrequency.monthly,
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(AppDimens.spacingXl),
              FTileGroup(
                label: const Text(Strings.data),
                description: const Text(Strings.dataSectionDescription),
                divider: FItemDivider.indented,
                children: [
                  // Forui widgets provide accessibility automatically from title/subtitle
                  FTile(
                    prefix: const Icon(FIcons.refreshCw),
                    title: Text(
                      isCheckingUpdates.value
                          ? Strings.checkingUpdatesInProgress
                          : Strings.checkUpdatesNow,
                    ),
                    subtitle: Text(
                      isCheckingUpdates.value
                          ? Strings.pleaseWaitSync
                          : Strings.checkUpdatesTitle,
                    ),
                    enabled: !isCheckingUpdates.value,
                    onPress: isCheckingUpdates.value ? null : runManualSync,
                    suffix: isCheckingUpdates.value
                        ? const SizedBox(
                            width: AppDimens.iconSm,
                            height: AppDimens.iconSm,
                            child: FCircularProgress.loader(),
                          )
                        : ExcludeSemantics(
                            child: Icon(
                              FIcons.chevronRight,
                              size: AppDimens.iconSm,
                              color: context.theme.colors.mutedForeground,
                            ),
                          ),
                  ),
                  // Forui widgets provide accessibility automatically from title/subtitle
                  FTile(
                    prefix: const Icon(FIcons.databaseZap),
                    title: const Text(Strings.forceReset),
                    subtitle: Text(
                      Strings.forceResetDescription,
                      style: context.theme.typography.sm.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                    onPress: showResetConfirmation,
                    suffix: ExcludeSemantics(
                      child: Icon(
                        FIcons.chevronRight,
                        size: AppDimens.iconSm,
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(AppDimens.spacingXl),
              FTileGroup(
                label: const Text(Strings.diagnostics),
                description: const Text(Strings.diagnosticsDescription),
                divider: FItemDivider.indented,
                children: [
                  // Forui widgets provide accessibility automatically from title/subtitle
                  FTile(
                    prefix: const Icon(FIcons.terminal),
                    title: const Text(Strings.showLogs),
                    subtitle: const Text(Strings.openDetailedViewForSupport),
                    onPress: () => const LogsRoute().push<void>(context),
                    suffix: ExcludeSemantics(
                      child: Icon(
                        FIcons.chevronRight,
                        size: AppDimens.iconSm,
                        color: context.theme.colors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isResetting.value)
            Positioned.fill(
              child: ColoredBox(
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
                      const Gap(AppDimens.spacingMd),
                      Text(
                        Strings.resetting,
                        style: context.theme.typography.base,
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

class _SyncProgressDialog extends StatelessWidget {
  const _SyncProgressDialog();

  @override
  Widget build(BuildContext context) {
    // WHY: Let showAdaptiveOverlay handle the screen size decision
    // Return FCard for both cases - adaptive_overlay will wrap it appropriately
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
            const Gap(AppDimens.spacingMd),
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
  }
}
