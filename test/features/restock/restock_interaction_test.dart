import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';
import 'package:pharma_scan/features/restock/presentation/providers/restock_provider.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

class MockRestockDao extends Mock implements RestockDao {}

void main() {
  setUpAll(() {
    registerFallbackValue(Cip13.validated('3400934056781'));
  });

  group('Restock interactions', () {
    late MockAppDatabase mockDb;
    late MockRestockDao mockRestockDao;
    late StreamController<List<RestockItemEntity>> restockStream;

    RestockItemEntity buildItem({
      required String cip,
      required String label,
      int quantity = 1,
      bool isChecked = false,
    }) {
      return RestockItemEntity(
        cip: Cip13.validated(cip),
        label: label,
        quantity: quantity,
        isChecked: isChecked,
        isPrinceps: false,
      );
    }

    setUp(() {
      mockDb = MockAppDatabase();
      mockRestockDao = MockRestockDao();
      restockStream = StreamController<List<RestockItemEntity>>.broadcast(
        sync: true,
      );

      when(() => mockDb.restockDao).thenReturn(mockRestockDao);
      when(
        () => mockRestockDao.updateQuantity(
          any(),
          any(),
          allowZero: any(named: 'allowZero'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockRestockDao.forceUpdateQuantity(
          cip: any(named: 'cip'),
          newQuantity: any(named: 'newQuantity'),
        ),
      ).thenAnswer((_) async {});
      when(() => mockRestockDao.deleteRestockItemFully(any())).thenAnswer(
        (_) async {
          if (!restockStream.isClosed) {
            restockStream.add([]);
            await restockStream.close();
          }
        },
      );
      when(() => mockRestockDao.toggleCheck(any())).thenAnswer((_) async {});
      when(
        () => mockRestockDao.watchRestockItems(),
      ).thenAnswer((_) => restockStream.stream);
    });

    tearDown(() async {
      if (!restockStream.isClosed) {
        await restockStream.close();
      }
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(mockDb),
          sortingPreferenceProvider.overrideWith(
            (ref) => Stream.value(SortingPreference.princeps),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('calls DAO methods on increment, decrement, toggle, delete', () async {
      final container = createContainer();
      final notifier = container.read(restockProvider.notifier);
      final item = buildItem(
        cip: '3400934056781',
        label: 'Doliprane 1000mg',
      );

      await notifier.increment(item);
      verify(() => mockRestockDao.updateQuantity(item.cip, 1)).called(1);

      await notifier.decrement(item);
      verify(
        () => mockRestockDao.updateQuantity(
          item.cip,
          -1,
          allowZero: true,
        ),
      ).called(1);

      await notifier.addBulk(item, 10);
      verify(() => mockRestockDao.updateQuantity(item.cip, 10)).called(1);

      await notifier.setQuantity(item, 5);
      verify(
        () => mockRestockDao.forceUpdateQuantity(
          cip: item.cip.toString(),
          newQuantity: 5,
        ),
      ).called(1);

      await notifier.toggleChecked(item);
      verify(() => mockRestockDao.toggleCheck(item.cip)).called(1);

      await notifier.deleteItem(item);
      verify(() => mockRestockDao.deleteRestockItemFully(item.cip)).called(1);
    });

    test('propagates errors when mutation fails', () async {
      when(
        () => mockRestockDao.updateQuantity(
          any(),
          any(),
          allowZero: any(named: 'allowZero'),
        ),
      ).thenThrow(Exception('mutation failed'));

      final container = createContainer();
      final notifier = container.read(restockProvider.notifier);
      final item = buildItem(
        cip: '3400934056781',
        label: 'Doliprane 1000mg',
      );

      await expectLater(
        notifier.increment(item),
        throwsA(isA<Exception>()),
      );
    });
  });
}
