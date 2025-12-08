import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/scroll_to_top_fab.dart';
import 'package:pharma_scan/core/widgets/testable.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/restock/presentation/providers/restock_provider.dart';
import 'package:pharma_scan/features/restock/presentation/widgets/restock_list_item.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

@RoutePage()
class RestockScreen extends HookConsumerWidget {
  const RestockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();

    final restockAsync = ref.watch(sortedRestockProvider);
    final sortingAsync = ref.watch(sortingPreferenceProvider);

    final sortingPreference = sortingAsync.maybeWhen<SortingPreference>(
      data: (value) => value,
      orElse: () => SortingPreference.princeps,
    );

    Future<void> switchToScanner() async {
      try {
        AutoTabsRouter.of(context).setActiveIndex(0);
      } on Object {
        // Not inside tab scaffold (tests/standalone).
      }
    }

    Future<bool> confirmDestructiveAction({
      required String title,
      required String description,
      required String confirmLabel,
    }) async {
      final result = await showShadDialog<bool>(
        context: context,
        builder: (context) {
          return ShadDialog.alert(
            title: Text(title),
            description: Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.spacingXs),
              child: Text(description),
            ),
            actions: [
              ShadButton.outline(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(Strings.cancel),
              ),
              ShadButton.destructive(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(confirmLabel),
              ),
            ],
          );
        },
      );
      return result ?? false;
    }

    Future<void> onClearChecked() async {
      final confirmed = await confirmDestructiveAction(
        title: Strings.restockClearChecked,
        description: Strings.restockClearCheckedDescription,
        confirmLabel: Strings.restockClearCheckedConfirm,
      );
      if (!confirmed) return;

      final notifier = ref.read(restockProvider.notifier);
      await notifier.clearChecked();
    }

    Future<void> onClearAll() async {
      final confirmed = await confirmDestructiveAction(
        title: Strings.restockClearAllTitle,
        description: Strings.restockClearAllDescription,
        confirmLabel: Strings.restockClearAllConfirm,
      );
      if (!confirmed) return;

      final notifier = ref.read(restockProvider.notifier);
      await notifier.clearAll();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          Strings.restockTitle,
          style: context.shadTextTheme.h4,
        ),
        actions: [
          ShadTooltip(
            builder: (context) => const Text(Strings.restockClearChecked),
            child: ShadIconButton.ghost(
              icon: const Icon(LucideIcons.check),
              onPressed: onClearChecked,
            ),
          ),
          ShadTooltip(
            builder: (context) => const Text(Strings.restockClearAll),
            child: ShadIconButton.ghost(
              icon: const Icon(LucideIcons.trash2),
              onPressed: onClearAll,
            ),
          ),
          Testable(
            id: TestTags.navSettings,
            child: ShadIconButton.ghost(
              icon: const Icon(LucideIcons.settings),
              onPressed: () =>
                  AutoRouter.of(context).push(const SettingsRoute()),
            ),
          ),
        ],
      ),
      body: restockAsync.when(
        loading: () => const Center(
          child: StatusView(type: StatusType.loading),
        ),
        error: (error, _) => Center(
          child: StatusView(
            type: StatusType.error,
            title: Strings.error,
            description: error.toString(),
          ),
        ),
        data: (grouped) {
          if (grouped.isEmpty) {
            return StatusView(
              type: StatusType.empty,
              title: Strings.restockEmptyTitle,
              description: Strings.restockEmpty,
              actionLabel: Strings.startScanning,
              onAction: switchToScanner,
            );
          }

          final totalQuantity = grouped.values
              .expand((group) => group)
              .fold<int>(0, (acc, item) => acc + item.quantity);

          final slivers = <Widget>[];

          grouped.forEach((letter, groupItems) {
            slivers.add(
              SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spacingMd,
                        vertical: AppDimens.spacingSm,
                      ),
                      child: Text(
                        letter,
                        style: context.shadTextTheme.small.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = groupItems[index];
                        return RestockListItem(
                          item: item,
                          showPrincepsSubtitle:
                              sortingPreference == SortingPreference.princeps &&
                              item.princepsLabel != null,
                          onIncrement: () => ref
                              .read(restockProvider.notifier)
                              .increment(item),
                          onDecrement: () => ref
                              .read(restockProvider.notifier)
                              .decrement(item),
                          onToggleChecked: () => ref
                              .read(restockProvider.notifier)
                              .toggleChecked(item),
                          onDismissed: (_) async {
                            final removedItem = item;
                            await ref
                                .read(restockProvider.notifier)
                                .deleteItem(removedItem);
                            if (!context.mounted) return;
                            ShadToaster.of(context).show(
                              ShadToast(
                                title: const Text(Strings.itemDeleted),
                                action: ShadButton.ghost(
                                  onPressed: () => ref
                                      .read(restockProvider.notifier)
                                      .restoreItem(removedItem),
                                  child: const Text(Strings.undo),
                                ),
                              ),
                            );
                          },
                        );
                      },
                      childCount: groupItems.length,
                    ),
                  ),
                ],
              ),
            );
          });

          return Stack(
            children: [
              CustomScrollView(
                controller: scrollController,
                slivers: slivers,
              ),
              Positioned(
                right: AppDimens.spacingMd,
                bottom:
                    AppDimens.spacingMd + MediaQuery.paddingOf(context).bottom,
                child: ScrollToTopFab(
                  controller: scrollController,
                  badgeCount: totalQuantity == 0 ? null : totalQuantity,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
