import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/mixins/safe_async_notifier_mixin.dart';
import 'package:pharma_scan/core/domain/types/unknown_value.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'restock_provider.g.dart';

@riverpod
class RestockNotifier extends _$RestockNotifier with SafeAsyncNotifierMixin {
  @override
  Stream<List<RestockItemEntity>> build() {
    return ref.read(restockDaoProvider).watchRestockItems();
  }

  Future<void> increment(RestockItemEntity item) async {
    final result = await safeExecute(() async {
      final db = ref.read(databaseProvider());
      await db.restockDao.updateQuantity(item.cip, 1);
    });

    if (!isMounted()) return;

    if (result.hasError) {
      logError(
        '[RestockNotifier] Failed to increment item ${item.cip}',
        result.error!,
        result.stackTrace ?? StackTrace.current,
      );
    }
  }

  Future<void> decrement(RestockItemEntity item) async {
    final result = await safeExecute(() async {
      final db = ref.read(databaseProvider());
      if (item.quantity == 0) {
        await deleteItem(item);
        return;
      }
      await db.restockDao.updateQuantity(
        item.cip,
        -1,
        allowZero: true,
      );
    });

    if (!isMounted()) return;

    if (result.hasError) {
      logError(
        '[RestockNotifier] Failed to decrement item ${item.cip}',
        result.error!,
        result.stackTrace ?? StackTrace.current,
      );
    }
  }

  Future<void> addBulk(RestockItemEntity item, int amount) async {
    final result = await safeExecute(() async {
      final db = ref.read(databaseProvider());
      await db.restockDao.updateQuantity(item.cip, amount);
    });

    if (!isMounted()) return;

    if (result.hasError) {
      logError(
        '[RestockNotifier] Failed to add bulk amount $amount to item ${item.cip}',
        result.error!,
        result.stackTrace ?? StackTrace.current,
      );
    }
  }

  Future<void> setQuantity(
    RestockItemEntity item,
    int quantity,
  ) async {
    if (quantity < 0) return;

    final result = await safeExecute(() async {
      final db = ref.read(databaseProvider());
      await db.restockDao.forceUpdateQuantity(
        cip: item.cip,
        newQuantity: quantity,
      );
    });

    if (!isMounted()) return;

    if (result.hasError) {
      logError(
        '[RestockNotifier] Failed to set quantity $quantity for item ${item.cip}',
        result.error!,
        result.stackTrace ?? StackTrace.current,
      );
    }
  }

  Future<void> toggleChecked(RestockItemEntity item) async {
    final result = await safeExecute(() async {
      final db = ref.read(databaseProvider());
      await db.restockDao.toggleCheck(item.cip);
    });

    if (!isMounted()) return;

    if (result.hasError) {
      logError(
        '[RestockNotifier] Failed to toggle checked status for item ${item.cip}',
        result.error!,
        result.stackTrace ?? StackTrace.current,
      );
    }
  }

  Future<void> deleteItem(RestockItemEntity item) async {
    final result = await safeExecute(() async {
      final db = ref.read(databaseProvider());
      await db.restockDao.deleteRestockItemFully(item.cip);
    });

    if (!isMounted()) return;

    if (result.hasError) {
      logError(
        '[RestockNotifier] Failed to delete item ${item.cip}',
        result.error!,
        result.stackTrace ?? StackTrace.current,
      );
    }
  }

  Future<void> restoreItem(RestockItemEntity item) async {
    final result = await safeExecute(() async {
      final db = ref.read(databaseProvider());
      await db.restockDao.forceUpdateQuantity(
        cip: item.cip,
        newQuantity: item.quantity,
      );
    });

    if (!isMounted()) return;

    if (result.hasError) {
      logError(
        '[RestockNotifier] Failed to restore item ${item.cip}',
        result.error!,
        result.stackTrace ?? StackTrace.current,
      );
    }
  }

  Future<void> clearChecked() async {
    final result = await safeExecute(() async {
      final db = ref.read(databaseProvider());
      await db.restockDao.clearChecked();
    });

    if (!isMounted()) return;

    if (result.hasError) {
      logError(
        '[RestockNotifier] Failed to clear checked items',
        result.error!,
        result.stackTrace ?? StackTrace.current,
      );
    }
  }

  Future<void> clearAll() async {
    final result = await safeExecute(() async {
      final db = ref.read(databaseProvider());
      await db.restockDao.clearAll();
    });

    if (!isMounted()) return;

    if (result.hasError) {
      logError(
        '[RestockNotifier] Failed to clear all items',
        result.error!,
        result.stackTrace ?? StackTrace.current,
      );
    }
  }
}

@riverpod
AsyncValue<Map<String, List<RestockItemEntity>>> sortedRestock(Ref ref) {
  final itemsAsync = ref.watch(restockProvider);
  final sortingAsync = ref.watch(sortingPreferenceProvider);

  if (sortingAsync.isLoading || !sortingAsync.hasValue) {
    return const AsyncValue.loading();
  }

  final sorting = sortingAsync.value!;

  return itemsAsync.when(
    data: (items) => AsyncValue.data(
      _groupByInitial(_sortRestockItems(items, sorting), sorting),
    ),
    error: AsyncValue.error,
    loading: AsyncValue.loading,
  );
}

List<RestockItemEntity> _sortRestockItems(
  List<RestockItemEntity> items,
  SortingPreference preference,
) {
  String keyFor(RestockItemEntity item) {
    switch (preference) {
      case SortingPreference.princeps:
        final princepsValue =
            UnknownAwareString.fromDatabase(item.princepsLabel);
        if (princepsValue.hasContent) {
          return princepsValue.value.toUpperCase();
        }
        final labelValue = UnknownAwareString.fromDatabase(item.label);
        return labelValue.value.toUpperCase();
      case SortingPreference.form:
        final formValue = UnknownAwareString.fromDatabase(item.form);
        if (formValue.hasContent) {
          return formValue.value.toUpperCase();
        }
        return Strings.restockFormUnknown;
      case SortingPreference.generic:
        final labelValue = UnknownAwareString.fromDatabase(item.label);
        return labelValue.value.toUpperCase();
    }
  }

  final sorted = [...items]..sort((a, b) {
      final ka = keyFor(a);
      final kb = keyFor(b);
      final keyCompare = ka.compareTo(kb);
      if (keyCompare != 0) return keyCompare;
      return a.label.toUpperCase().compareTo(b.label.toUpperCase());
    });
  return sorted;
}

Map<String, List<RestockItemEntity>> _groupByInitial(
  List<RestockItemEntity> items,
  SortingPreference preference,
) {
  final groups = <String, List<RestockItemEntity>>{};

  bool hasValidPrinceps(RestockItemEntity item) {
    final princepsValue = UnknownAwareString.fromDatabase(item.princepsLabel);
    return princepsValue.hasContent;
  }

  String letterFor(RestockItemEntity item) {
    if (preference == SortingPreference.form) {
      final formValue = UnknownAwareString.fromDatabase(item.form);
      if (!formValue.hasContent) return Strings.restockFormUnknown;
      return formValue.value.trim().toUpperCase();
    }

    final base =
        preference == SortingPreference.princeps && hasValidPrinceps(item)
            ? item.princepsLabel!
            : item.label;

    final baseValue = UnknownAwareString.fromDatabase(base);
    if (!baseValue.hasContent) return '#';

    final first = baseValue.value[0].toUpperCase();
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
