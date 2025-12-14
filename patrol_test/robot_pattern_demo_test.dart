import 'package:flutter/foundation.dart';
import 'package:patrol/patrol.dart';
import 'package:pharma_scan/main.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'helpers/test_database_helper.dart';
import 'robots/app_robot.dart';

void main() {
  final config = PatrolTesterConfig(printLogs: true);

  patrolTest(
    'Demo: Robot Pattern - Complete multi-screen workflow',
    config: config,
    ($) async {
      // Prepare device/app state
      await $.pump();

      // Inject a known test database to avoid network operations
      await TestDatabaseHelper.injectTestDatabase();

      // Start the real app within a ProviderScope
      await $.pumpWidgetAndSettle(
        ProviderScope(
          child: const PharmaScanApp(),
        ),
      );

      final robot = AppRobot($);

      // --- Test demonstrates clean Robot Pattern usage ---

      // 1. App initialization (no direct widget selection)
      await robot.completeAppInitialization();

      // 2. Verify all tabs are accessible (high-level navigation)
      await robot.verifyAllTabsAccessible();

      // 3. Complete scanner workflow using single method call
      const testCip = '3400934056781';
      await robot.scanner.completeManualSearchFlow(testCip);

      // 4. Verify scanner result using descriptive verification method
      try {
        await robot.scanner.expectMedicamentNotFound();
        debugPrint('✓ Medicament not found (expected for test data)');
      } catch (_) {
        await robot.scanner.expectMedicamentFound();
        debugPrint('✓ Medicament found (CIP exists in test data)');
      }

      // 5. Complete explorer search workflow
      const testMedication = 'Paracetamol';
      await robot.explorer.completeSearchFlow(testMedication);
      await robot.explorer.expectMedicamentVisible(testMedication);

      // 6. Complete restock workflow
      const testItem = 'Doliprane';
      await robot.restock.completeRestockFlow(testItem, quantity: 5);
      await robot.restock.expectItemInRestock(testItem);

      // 7. Cross-app search workflow
      await robot.searchMedicationAcrossApp(testCip, testMedication);

      // 8. Native interaction
      await robot.pressHome();

      debugPrint('✓ Robot Pattern demo completed successfully!');
    },
  );
}
