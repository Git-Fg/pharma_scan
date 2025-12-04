import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/main.dart';
import '../test/fixtures/seed_builder.dart';
import '../test/robots/restock_robot.dart';
import '../test/test_utils.dart' show setPrincipeNormalizedForAllPrinciples;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Restock Persistence Flow - Offline-First Critical Test', () {
    testWidgets(
      'should persist data across app restart (kill & relaunch simulation)',
      (WidgetTester tester) async {
        final tempDir = await Directory.systemTemp.createTemp(
          'pharma_scan_restock_test_',
        );
        final dbFile = File(p.join(tempDir.path, 'medicaments.db'));

        final database = AppDatabase.forTesting(
          NativeDatabase(dbFile, setup: configureAppSQLite),
        );

        await SeedBuilder()
            .inGroup('GROUP_PARACETAMOL', 'PARACETAMOL 500 mg')
            .addPrinceps(
              'PARACETAMOL 500 mg, comprimé',
              '3400930302613',
              cis: 'CIS_PARACETAMOL',
              dosage: '500',
              form: 'Comprimé',
              lab: 'SANOFI',
            )
            .inGroup('GROUP_IBUPROFENE', 'IBUPROFENE 400 mg')
            .addPrinceps(
              'IBUPROFENE 400 mg, comprimé',
              '3400930302614',
              cis: 'CIS_IBUPROFENE',
              dosage: '400',
              form: 'Comprimé',
              lab: 'SANDOZ',
            )
            .insertInto(database);

        await setPrincipeNormalizedForAllPrinciples(database);
        final dataInit = DataInitializationService(database: database);
        await dataInit.runSummaryAggregationForTesting();

        await database.settingsDao.updateBdpmVersion(
          DataInitializationService.dataVersion,
        );

        final container1 = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container1,
            child: const PharmaScanApp(),
          ),
        );

        await tester.pumpAndSettle(const Duration(seconds: 2));

        final restockTab = find.text(Strings.restockTabLabel);
        expect(restockTab, findsOneWidget);
        await tester.tap(restockTab);
        await tester.pumpAndSettle();

        expect(find.text(Strings.restockTitle), findsOneWidget);

        final restockDao = database.restockDao;

        final cip1 = Cip13.validated('3400930302613');
        final cip2 = Cip13.validated('3400930302614');

        await restockDao.addToRestock(cip1);
        await restockDao.addToRestock(cip2);
        await tester.pumpAndSettle();

        final robot = RestockRobot(tester);
        robot.expectItemCount(2);

        await robot.tapIncrement('PARACETAMOL 500 mg, comprimé');
        await robot.tapIncrement('PARACETAMOL 500 mg, comprimé');
        await robot.tapIncrement('PARACETAMOL 500 mg, comprimé');
        await robot.tapIncrement('PARACETAMOL 500 mg, comprimé');
        await robot.tapIncrement('PARACETAMOL 500 mg, comprimé');

        robot.expectQuantity('PARACETAMOL 500 mg, comprimé', 6);

        await robot.toggleCheckbox('PARACETAMOL 500 mg, comprimé');
        robot.expectTotalChecked(1);

        await database.close();
        container1.dispose();

        final database2 = AppDatabase.forTesting(
          NativeDatabase(dbFile, setup: configureAppSQLite),
        );

        final container2 = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(database2)],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container2,
            child: const PharmaScanApp(),
          ),
        );

        await tester.pumpAndSettle(const Duration(seconds: 2));

        await tester.tap(restockTab);
        await tester.pumpAndSettle();

        final robot2 = RestockRobot(tester);
        robot2.expectItemCount(2);
        robot2.expectQuantity('PARACETAMOL 500 mg, comprimé', 6);
        robot2.expectTotalChecked(1);

        await database2.close();
        await tempDir.delete(recursive: true);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
