import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/domain/types/unknown_value.dart';
import 'package:pharma_scan/core/domain/entities/restock_item_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';

part 'restock_provider.g.dart';

@riverpod
class RestockNotifier extends _$RestockNotifier {
  @override
  Stream<List<RestockItemEntity>> build() {
    return ref.read(restockDaoProvider).watchRestockItems();
  }

  Future<void> _withErrorHandler(
    String operation,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e, s) {
      ref.read(loggerProvider).error(operation, e, s);
    }
  }

  Future<void> increment(RestockItemEntity item) async {
    await _withErrorHandler(
      '[RestockNotifier] Failed to increment item ${item.cip}',
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.updateQuantity(item.cip, 1);
      },
    );
  }

  Future<void> decrement(RestockItemEntity item) async {
    await _withErrorHandler(
      '[RestockNotifier] Failed to decrement item ${item.cip}',
      () async {
        final db = ref.read(databaseProvider());
        if (item.quantity == 0) {
          await deleteItem(item);
          return;
        }
        await db.restockDao.updateQuantity(item.cip, -1, allowZero: true);
      },
    );
  }

  Future<void> addBulk(RestockItemEntity item, int amount) async {
    await _withErrorHandler(
      '[RestockNotifier] Failed to add bulk amount $amount to item ${item.cip}',
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.updateQuantity(item.cip, amount);
      },
    );
  }

  Future<void> setQuantity(RestockItemEntity item, int quantity) async {
    if (quantity < 0) return;
    await _withErrorHandler(
      '[RestockNotifier] Failed to set quantity $quantity for item ${item.cip}',
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.forceUpdateQuantity(
          cip: item.cip,
          newQuantity: quantity,
        );
      },
    );
  }

  Future<void> toggleChecked(RestockItemEntity item) async {
    await _withErrorHandler(
      '[RestockNotifier] Failed to toggle checked status for item ${item.cip}',
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.toggleCheck(item.cip);
      },
    );
  }

  Future<void> deleteItem(RestockItemEntity item) async {
    await _withErrorHandler(
      '[RestockNotifier] Failed to delete item ${item.cip}',
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.deleteRestockItemFully(item.cip);
      },
    );
  }

  Future<void> restoreItem(RestockItemEntity item) async {
    await _withErrorHandler(
      '[RestockNotifier] Failed to restore item ${item.cip}',
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.forceUpdateQuantity(
          cip: item.cip,
          newQuantity: item.quantity,
        );
      },
    );
  }

  Future<void> clearChecked() async {
    await _withErrorHandler(
      '[RestockNotifier] Failed to clear checked items',
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.clearChecked();
      },
    );
  }

  Future<void> clearAll() async {
    await _withErrorHandler(
      '[RestockNotifier] Failed to clear all items',
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.clearAll();
      },
    );
  }

  Future<void> addByCip(Cip13 cip) async {
    await _withErrorHandler(
      '[RestockNotifier] Failed to add CIP $cip',
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.addToRestock(cip);
      },
    );
  }

  Future<void> addManual({
    required String princeps,
    String? generic,
    int quantity = 1,
  }) async {
    await _withErrorHandler(
      '[RestockNotifier] Failed to add manual item $princeps',
      () async {
        final db = ref.read(databaseProvider());
        await db.restockDao.addManualToRestock(
          princeps: princeps,
          generic: generic,
          quantity: quantity,
        );
      },
    );
  }

  Future<void> debugPopulate() async {
    await _withErrorHandler(
      '[RestockNotifier] Failed to populate debug data',
      () async {
        final db = ref.read(databaseProvider());
        final result = await db
            .customSelect(
              'SELECT cip_code FROM medicaments ORDER BY RANDOM() LIMIT 20',
            )
            .get();

        for (final row in result) {
          final cip = row.read<String>('cip_code');
          await db.restockDao.updateQuantity(Cip13(cip), 1);
        }
      },
    );
  }
}

@riverpod
AsyncValue<Map<String, List<RestockItemEntity>>> sortedRestock(Ref ref) {
  final itemsAsync = ref.watch(restockProvider);
  final sortingAsync = ref.watch(sortingPreferenceProvider);

  if (sortingAsync.isLoading || !sortingAsync.hasValue) {
    return const .loading();
  }

  final sorting = sortingAsync.value!;

  return itemsAsync.when(
    data: (items) =>
        .data(_groupByInitial(_sortRestockItems(items, sorting), sorting)),
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
      case .princeps:
        final princepsValue = UnknownAwareString.fromDatabase(
          item.princepsLabel,
        );
        if (princepsValue.hasContent) {
          return princepsValue.value.toUpperCase();
        }
        final labelValue = UnknownAwareString.fromDatabase(item.label);
        return labelValue.value.toUpperCase();
      case .form:
        final formValue = UnknownAwareString.fromDatabase(item.form);
        if (formValue.hasContent) {
          return formValue.value.toUpperCase();
        }
        return Strings.restockFormUnknown;
      case .generic:
        final labelValue = UnknownAwareString.fromDatabase(item.label);
        return labelValue.value.toUpperCase();
    }
  }

  final sorted = [...items]
    ..sort((a, b) {
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
    if (preference == .form) {
      final formValue = UnknownAwareString.fromDatabase(item.form);
      if (!formValue.hasContent) return Strings.restockFormUnknown;
      return formValue.value.trim().toUpperCase();
    }

    if (preference == SortingPreference.princeps && hasValidPrinceps(item)) {
      final pLabel = item.princepsLabel!.trim();
      if (pLabel.isNotEmpty) {
        final first = pLabel[0].toUpperCase();
        return RegExp(r'[A-ZÀ-ÖØ-Ý]').hasMatch(first) ? first : '#';
      }
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
