import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';
import 'package:pharma_scan/features/restock/presentation/providers/restock_provider.dart';
import 'package:pharma_scan/features/restock/presentation/widgets/restock_list_item.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

@RoutePage()
class RestockScreen extends ConsumerWidget {
  const RestockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restockAsync = ref.watch(restockListProvider);
    final sortingAsync = ref.watch(sortingPreferenceProvider);

    final sortingPreference = sortingAsync.maybeWhen(
      data: (value) => value,
      orElse: () => SortingPreference.princeps,
    );

    Future<void> onClearChecked() async {
      final notifier = ref.read(restockMutationProvider.notifier);
      await notifier.clearChecked();
    }

    Future<void> onClearAll() async {
      final confirmed = await showShadDialog<bool>(
        context: context,
        builder: (context) {
          return ShadDialog.alert(
            title: const Text(Strings.restockClearAllTitle),
            description: const Text(Strings.restockClearAllDescription),
            actions: [
              ShadButton.outline(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(Strings.cancel),
              ),
              ShadButton.destructive(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(Strings.restockClearAllConfirm),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;

      final notifier = ref.read(restockMutationProvider.notifier);
      await notifier.clearAll();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          Strings.restockTitle,
          style: context.shadTextTheme.h4,
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.check),
            tooltip: Strings.restockClearChecked,
            onPressed: onClearChecked,
          ),
          IconButton(
            icon: const Icon(LucideIcons.trash2),
            tooltip: Strings.restockClearAll,
            onPressed: onClearAll,
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
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spacingLg),
                child: Text(
                  Strings.restockEmpty,
                  style: context.shadTextTheme.p,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final sorted = _sortItems(items, sortingPreference);
          final grouped = _groupByInitial(sorted, sortingPreference);

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
                              .read(restockMutationProvider.notifier)
                              .increment(item),
                          onDecrement: () => ref
                              .read(restockMutationProvider.notifier)
                              .decrement(item),
                          onToggleChecked: () => ref
                              .read(restockMutationProvider.notifier)
                              .toggleChecked(item),
                          onDismissed: (_) => ref
                              .read(restockMutationProvider.notifier)
                              .deleteItem(item),
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
            slivers: slivers,
          );
        },
      ),
    );
  }

  List<RestockItemEntity> _sortItems(
    List<RestockItemEntity> items,
    SortingPreference preference,
  ) {
    final sorted = [...items];
    int compare(RestockItemEntity a, RestockItemEntity b) {
      String keyFor(RestockItemEntity item) {
        if (preference == SortingPreference.princeps &&
            item.princepsLabel != null &&
            item.princepsLabel!.trim().isNotEmpty) {
          return item.princepsLabel!.trim().toUpperCase();
        }
        return item.label.trim().toUpperCase();
      }

      final ka = keyFor(a);
      final kb = keyFor(b);
      final keyCompare = ka.compareTo(kb);
      if (keyCompare != 0) return keyCompare;
      return a.label.toUpperCase().compareTo(b.label.toUpperCase());
    }

    sorted.sort(compare);
    return sorted;
  }

  Map<String, List<RestockItemEntity>> _groupByInitial(
    List<RestockItemEntity> items,
    SortingPreference preference,
  ) {
    final groups = <String, List<RestockItemEntity>>{};

    String letterFor(RestockItemEntity item) {
      final base =
          preference == SortingPreference.princeps &&
              item.princepsLabel != null &&
              item.princepsLabel!.trim().isNotEmpty
          ? item.princepsLabel!
          : item.label;
      final trimmed = base.trim();
      if (trimmed.isEmpty) return '#';
      final first = trimmed[0].toUpperCase();
      final isAlpha = RegExp('[A-ZÀ-ÖØ-Ý]').hasMatch(first);
      return isAlpha ? first : '#';
    }

    for (final item in items) {
      final letter = letterFor(item);
      groups.putIfAbsent(letter, () => []).add(item);
    }

    final sortedKeys = groups.keys.toList()..sort();
    final sortedGroups = <String, List<RestockItemEntity>>{};
    for (final key in sortedKeys) {
      sortedGroups[key] = groups[key]!;
    }
    return sortedGroups;
  }
}
