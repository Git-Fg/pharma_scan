import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/mixins/safe_async_notifier_mixin.dart';
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
    final result = await safeExecute(
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.updateQuantity(item.cip, 1);
      },
      operationName: 'RestockNotifier.increment',
    );

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
    final result = await safeExecute(
      () async {
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
      },
      operationName: 'RestockNotifier.decrement',
    );

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
    final result = await safeExecute(
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.updateQuantity(item.cip, amount);
      },
      operationName: 'RestockNotifier.addBulk',
    );

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

    final result = await safeExecute(
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.forceUpdateQuantity(
          cip: item.cip,
          newQuantity: quantity,
        );
      },
      operationName: 'RestockNotifier.setQuantity',
    );

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
    final result = await safeExecute(
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.toggleCheck(item.cip);
      },
      operationName: 'RestockNotifier.toggleChecked',
    );

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
    final result = await safeExecute(
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.deleteRestockItemFully(item.cip);
      },
      operationName: 'RestockNotifier.deleteItem',
    );

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
    final result = await safeExecute(
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.forceUpdateQuantity(
          cip: item.cip,
          newQuantity: item.quantity,
        );
      },
      operationName: 'RestockNotifier.restoreItem',
    );

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
    final result = await safeExecute(
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.clearChecked();
      },
      operationName: 'RestockNotifier.clearChecked',
    );

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
    final result = await safeExecute(
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.clearAll();
      },
      operationName: 'RestockNotifier.clearAll',
    );

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

  return itemsAsync.when(
    data: (items) => AsyncValue.data(
      _groupByInitial(_sortRestockItems(items, sortingAsync), sortingAsync),
    ),
    error: AsyncValue.error,
    loading: AsyncValue.loading,
  );
}

List<RestockItemEntity> _sortRestockItems(
  List<RestockItemEntity> items,
  SortingPreference preference,
) {
  bool hasValidPrinceps(RestockItemEntity item) {
    final label = item.princepsLabel?.trim();
    if (label == null || label.isEmpty) return false;
    return label.toUpperCase() != Strings.unknown.toUpperCase();
  }

  String keyFor(RestockItemEntity item) {
    switch (preference) {
      case SortingPreference.princeps:
        if (hasValidPrinceps(item)) {
          return item.princepsLabel!.trim().toUpperCase();
        }
        return item.label.trim().toUpperCase();
      case SortingPreference.form:
        final form = item.form?.trim();
        if (form != null && form.isNotEmpty) {
          return form.toUpperCase();
        }
        return Strings.restockFormUnknown;
      case SortingPreference.generic:
        return item.label.trim().toUpperCase();
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
    final label = item.princepsLabel?.trim();
    if (label == null || label.isEmpty) return false;
    return label.toUpperCase() != Strings.unknown.toUpperCase();
  }

  String letterFor(RestockItemEntity item) {
    if (preference == SortingPreference.form) {
      final form = item.form?.trim();
      if (form == null || form.isEmpty) return Strings.restockFormUnknown;
      return form.trim().toUpperCase();
    }
    final base =
        preference == SortingPreference.princeps && hasValidPrinceps(item)
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

