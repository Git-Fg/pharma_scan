import 'package:meta/meta.dart';
import 'package:pharma_scan/core/database/providers.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'restock_provider.g.dart';

@riverpod
class RestockNotifier extends _$RestockNotifier {
  @override
  Stream<List<RestockItemEntity>> build() {
    return ref.watch(databaseProvider).restockDao.watchRestockItems();
  }

  Future<void> increment(RestockItemEntity item) async {
    final db = ref.read(databaseProvider);
    await db.restockDao.updateQuantity(item.cip, 1);
  }

  Future<void> decrement(RestockItemEntity item) async {
    final db = ref.read(databaseProvider);
    if (item.quantity == 0) {
      await deleteItem(item);
      return;
    }
    await db.restockDao.updateQuantity(
      item.cip,
      -1,
      allowZero: true,
    );
  }

  Future<void> addBulk(RestockItemEntity item, int amount) async {
    final db = ref.read(databaseProvider);
    await db.restockDao.updateQuantity(item.cip, amount);
  }

  Future<void> setQuantity(
    RestockItemEntity item,
    int quantity,
  ) async {
    if (quantity < 0) return;
    final db = ref.read(databaseProvider);
    await db.restockDao.forceUpdateQuantity(
      cip: item.cip,
      newQuantity: quantity,
    );
  }

  Future<void> toggleChecked(RestockItemEntity item) async {
    final db = ref.read(databaseProvider);
    await db.restockDao.toggleCheck(item.cip);
  }

  Future<void> deleteItem(RestockItemEntity item) async {
    final db = ref.read(databaseProvider);
    await db.restockDao.deleteRestockItemFully(item.cip);
  }

  Future<void> restoreItem(RestockItemEntity item) async {
    final db = ref.read(databaseProvider);
    await db.restockDao.forceUpdateQuantity(
      cip: item.cip,
      newQuantity: item.quantity,
    );
  }

  Future<void> clearChecked() async {
    final db = ref.read(databaseProvider);
    await db.restockDao.clearChecked();
  }

  Future<void> clearAll() async {
    final db = ref.read(databaseProvider);
    await db.restockDao.clearAll();
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

@visibleForTesting
List<RestockItemEntity> sortRestockItemsForTest(
  List<RestockItemEntity> items,
  SortingPreference preference,
) =>
    _sortRestockItems(items, preference);

@visibleForTesting
Map<String, List<RestockItemEntity>> groupRestockItemsForTest(
  List<RestockItemEntity> items,
  SortingPreference preference,
) =>
    _groupByInitial(items, preference);
