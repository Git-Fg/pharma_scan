// integration_test/restock_interaction_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';
import 'package:pharma_scan/features/restock/presentation/providers/restock_provider.dart';

import '../test/mocks.dart';
import 'helpers/golden_db_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Restock interactions - delete with undo', () {
    test('delete then restore via notifier', () async {
      // Load golden database instead of manual seeding
      final db = await loadGoldenDatabase();

      final mockDataInit = MockDataInitializationService();
      when(
        () => mockDataInit.initializeDatabase(
          forceRefresh: any(named: 'forceRefresh'),
        ),
      ).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          databaseProvider().overrideWithValue(db),
          dataInitializationServiceProvider.overrideWithValue(mockDataInit),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(db.close);

      // Get a real medication from the golden database
      final summaries = await (db.select(db.medicamentSummary)..limit(1)).get();
      expect(summaries, isNotEmpty, reason: 'Golden DB should have data');

      final testMed = summaries.first;
      final cip = testMed.representativeCip != null
          ? Cip13.validated(testMed.representativeCip!)
          : Cip13.validated('3400930000001'); // Fallback if no CIP

      final restockDao = db.restockDao;
      await restockDao.addToRestock(cip);

      var rows = await db.select(db.restockItems).get();
      expect(rows, hasLength(1));

      final notifier = container.read(restockProvider.notifier);
      final entity = RestockItemEntity(
        cip: cip,
        label: testMed.nomCanonique,
        princepsLabel: testMed.princepsDeReference,
        form: testMed.formePharmaceutique ?? '',
        quantity: 1,
        isChecked: false,
        isPrinceps: testMed.isPrinceps,
      );

      await notifier.deleteItem(entity);
      rows = await db.select(db.restockItems).get();
      expect(rows, isEmpty);

      await notifier.restoreItem(entity);
      rows = await db.select(db.restockItems).get();
      expect(rows, hasLength(1));
      expect(rows.single.stockCount, 1);
    });
  });
}
