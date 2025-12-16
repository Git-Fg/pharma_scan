import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/hooks/use_app_header.dart';
import 'package:pharma_scan/core/hooks/use_tab_reselection.dart';

import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/services/haptic_service.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
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
    final spacing = context.spacing;

    final restockAsync = ref.watch(sortedRestockProvider);
    final sortingAsync = ref.watch(sortingPreferenceProvider);
    final haptics = ref.watch(hapticServiceProvider);

    final sortingPreference = sortingAsync;

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
              padding: EdgeInsets.only(bottom: spacing.xs),
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

    // Setup tab reselection for restock tab (index 2)
    useTabReselection(
      ref: ref,
      controller: scrollController,
      tabIndex: 2,
      animationDuration: const Duration(milliseconds: 250),
      animationCurve: Curves.easeOut,
    );

    useAppHeader(
      title: Text(
        Strings.restockTitle,
        style: context.typo.h4,
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
      ],
    );

    return restockAsync.when(
      data: (grouped) {
        final slivers = <Widget>[];

        grouped.forEach((letter, groupItems) {
          slivers.add(
            SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.md,
                      vertical: spacing.sm,
                    ),
                    child: Text(
                      letter,
                      style: context.typo.small.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = groupItems[index];
                      final notifier = ref.read(restockProvider.notifier);
                      return RestockListItem(
                        item: item,
                        showPrincepsSubtitle:
                            sortingPreference == SortingPreference.princeps &&
                                item.princepsLabel != null,
                        haptics: haptics,
                        onIncrement: () => notifier.increment(item),
                        onDecrement: () => notifier.decrement(item),
                        onAddTen: () => notifier.addBulk(item, 10),
                        onSetQuantity: (value) =>
                            notifier.setQuantity(item, value),
                        onToggleChecked: () => notifier.toggleChecked(item),
                        onDismissed: (direction) async {
                          final removedItem = item;
                          await notifier.deleteItem(removedItem);
                          if (!context.mounted) return;
                          ShadToaster.of(context).show(
                            ShadToast(
                              title: const Text(Strings.itemDeleted),
                              description: Text(
                                '${item.quantity} x ${item.label}',
                              ),
                              action: ShadButton.outline(
                                size: ShadButtonSize.sm,
                                width: 120,
                                onPressed: () async {
                                  await notifier.restoreItem(removedItem);
                                  if (!context.mounted) return;
                                  await ShadToaster.of(context).hide();
                                },
                                child: const Text(Strings.undo),
                              ),
                              duration: const Duration(seconds: 4),
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

        return CustomScrollView(
          key: const Key(TestTags.restockList),
          controller: scrollController,
          slivers: slivers,
        );
      },
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
    );
  }
}
