import 'dart:io' show File;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';
import 'package:pharma_scan/features/restock/presentation/providers/restock_provider.dart';

import '../test/fixtures/seed_builder.dart';
import '../test/mocks.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Restock interactions - delete with undo', () {
    test('delete then restore via notifier', () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      final mockDataInit = MockDataInitializationService();
      when(
        () => mockDataInit.initializeDatabase(
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockDataInit.applyUpdate(any<Map<String, File>>()),
      ).thenAnswer((_) async {
        return null;
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          dataInitializationServiceProvider.overrideWithValue(mockDataInit),
        ],
      );
      addTearDown(container.dispose);

      await SeedBuilder()
          .inGroup('GRP_PARA', 'Paracetamol Group')
          .addPrinceps(
            'Paracetamol Princeps',
            '3400000000001',
            cis: 'CIS_PARA_1',
            dosage: '500',
            form: 'Comprimé',
          )
          .insertInto(db);
      await db.databaseDao.populateSummaryTable();
      await db.databaseDao.populateFts5Index();

      final restockDao = db.restockDao;
      final cip = Cip13.validated('3400000000001');
      await restockDao.addToRestock(cip);

      var rows = await db.select(db.restockItems).get();
      expect(rows, hasLength(1));

      final notifier = container.read(restockProvider.notifier);
      final entity = RestockItemEntity(
        cip: cip,
        label: 'Paracetamol Princeps',
        princepsLabel: 'Paracetamol Princeps',
        form: 'Comprimé',
        quantity: 1,
        isChecked: false,
        isPrinceps: true,
      );

      await notifier.deleteItem(entity);
      rows = await db.select(db.restockItems).get();
      expect(rows, isEmpty);

      await notifier.restoreItem(entity);
      rows = await db.select(db.restockItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.quantity, 1);
    });
  });
}
