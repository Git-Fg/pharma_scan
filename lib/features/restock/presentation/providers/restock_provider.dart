import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'restock_provider.g.dart';

@riverpod
Stream<List<RestockItemEntity>> restockList(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.restockDao.watchRestockItems();
}

@riverpod
class RestockMutation extends _$RestockMutation {
  @override
  Future<void> build() async {}

  Future<void> increment(RestockItemEntity item) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(appDatabaseProvider);
      await db.restockDao.updateQuantity(item.cip, 1);
    });
  }

  Future<void> decrement(RestockItemEntity item) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(appDatabaseProvider);
      await db.restockDao.updateQuantity(item.cip, -1);
    });
  }

  Future<void> toggleChecked(RestockItemEntity item) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(appDatabaseProvider);
      await db.restockDao.toggleCheck(item.cip);
    });
  }

  Future<void> deleteItem(RestockItemEntity item) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(appDatabaseProvider);
      await db.restockDao.updateQuantity(item.cip, -item.quantity);
    });
  }

  Future<void> clearChecked() async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(appDatabaseProvider);
      await db.restockDao.clearChecked();
    });
  }

  Future<void> clearAll() async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(appDatabaseProvider);
      await db.restockDao.clearAll();
    });
  }
}
