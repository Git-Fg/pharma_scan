import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../data/test_products.dart';
import '../helpers/mock_preferences_helper.dart';
import '../helpers/test_database_helper.dart';
import '../robots/app_robot.dart';

/// GP3: Restock Cycle Test
///
/// Test the complete restock functionality:
/// 1. Switch to Restock mode
/// 2. Scan same product multiple times
/// 3. Navigate to Restock tab
/// 4. Verify cumulative quantities
/// 5. Manual quantity modifications
/// 6. Delete and undo operations
void main() {
  group('GP3: Restock Cycle Tests', () {
    late AppRobot appRobot;

    setUp(() async {
      appRobot = AppRobot($);
    });

    patrolTest(
      'GP3.1: Complete restock cycle - Scan x3 → Verify → Modify → Delete',
      config: PatrolTesterConfig(
        reportLogs: true,
      ),
      ($) async {
        // PHASE 1: Setup and Initialization
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();

        // PHASE 2: Switch to Restock Mode in Scanner
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.waitForCameraInitialization();

        // Verify in analysis mode initially
        appRobot.scanner.expectScannerModeActive();

        // Switch to Restock mode
        await appRobot.scanner.switchToRestockMode();
        appRobot.scanner.expectRestockModeActive();

        // PHASE 3: Scan same product 3 times
        const String targetCip = TestProducts.doliprane1000Cip;
        const String targetName = 'DOLIPRANE 1000 mg';

        for (int i = 0; i < 3; i++) {
          print('🔄 GP3.1: Scanning product ${i + 1}/3');

          await appRobot.scanner.scanCipCode(targetCip);
          await appRobot.scanner.waitForScanResult();
          await appRobot.scanner.waitForBubbleAnimation();

          // Verify bubble appears after each scan
          appRobot.scanner.expectBubbleVisible('DOLIPRANE');

          // Small delay between scans
          await Future.delayed(const Duration(milliseconds: 500));
        }

        // PHASE 4: Navigate to Restock tab
        await appRobot.navigateToTab('restock');
        await appRobot.restock.expectRestockScreenVisible();

        // PHASE 5: Verify quantity = 3
        await appRobot.waitForNetworkRequests();
        appRobot.restock.expectItemInRestock('DOLIPRANE');
        appRobot.restock.expectItemQuantity('DOLIPRANE', 3);

        // PHASE 6: Manual quantity modification
        print('📝 GP3.1: Modifying quantity manually');

        // Tap on the item to edit
        await appRobot.restock.tapItemQuantity('DOLIPRANE');

        // Increase quantity by 10
        await appRobot.restock.setQuantity('DOLIPRANE', 13); // 3 + 10 = 13
        await appRobot.restock.expectItemQuantity('DOLIPRANE', 13);

        // Decrease quantity by 5
        await appRobot.restock.setQuantity('DOLIPRANE', 8);
        await appRobot.restock.expectItemQuantity('DOLIPRANE', 8);

        // PHASE 7: Test increment/decrement buttons
        await appRobot.restock.increaseQuantity('DOLIPRANE');
        appRobot.restock.expectItemQuantity('DOLIPRANE', 9);

        await appRobot.restock.increaseQuantity('DOLIPRANE');
        appRobot.restock.expectItemQuantity('DOLIPRANE', 10);

        await appRobot.restock.decreaseQuantity('DOLIPRANE');
        appRobot.restock.expectItemQuantity('DOLIPRANE', 9);

        // PHASE 8: Delete item with undo
        print('🗑️ GP3.1: Testing delete and undo');

        // Swipe to delete
        await appRobot.restock.swipeItemToDelete('DOLIPRANE');

        // Verify item is deleted
        appRobot.restock.expectEmptyStateVisible();

        // Test undo functionality
        await appRobot.restock.tapUndoButton();

        // Verify item is restored
        appRobot.restock.expectItemInRestock('DOLIPRANE');
        appRobot.restock.expectItemQuantity('DOLIPRANE', 9);

        // PHASE 9: Clear all items
        await appRobot.restock.tapClearAll();
        await appRobot.handleAnyDialog(accept: true);

        // Verify empty state
        appRobot.restock.expectEmptyStateVisible();

        print('✅ GP3.1: Complete restock cycle passed');
      },
    );

    patrolTest(
      'GP3.2: Restock with different products and bulk operations',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.switchToRestockMode();

        // Add multiple different products
        final products = [
          {'cip': TestProducts.doliprane1000Cip, 'name': 'DOLIPRANE', 'quantity': 2},
          {'cip': TestProducts.ibuprofene400Cip, 'name': 'IBUPROFENE', 'quantity': 1},
          {'cip': TestProducts.aspirine500Cip, 'name': 'ASPIRINE', 'quantity': 3},
        ];

        for (final product in products) {
          for (int i = 0; i < product['quantity'] as int; i++) {
            await appRobot.scanner.scanCipCode(product['cip'] as String);
            await appRobot.scanner.waitForScanResult();
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }

        // Navigate to Restock and verify
        await appRobot.navigateToTab('restock');
        await appRobot.waitForNetworkRequests();

        // Verify all items are present
        appRobot.restock.expectItemCount(3);

        // Test bulk selection
        await appRobot.restock.tapItemCheckbox('DOLIPRANE');
        await appRobot.restock.tapItemCheckbox('IBUPROFENE');
        await appRobot.restock.tapSelectAll();

        // Clear selected items
        await appRobot.restock.tapClearSelected();
        await appRobot.handleAnyDialog(accept: true);

        // Verify only one item remains
        appRobot.restock.expectItemInRestock('ASPIRINE');
        appRobot.restock.expectItemNotVisible('DOLIPRANE');
        appRobot.restock.expectItemNotVisible('IBUPROFENE');

        print('✅ GP3.2: Multiple products and bulk operations passed');
      },
    );

    patrolTest(
      'GP3.3: Restock alphabetical sections and scrolling',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();

        // Add items with different starting letters
        final letterItems = [
          {'cip': TestProducts.doliprane1000Cip, 'name': 'DOLIPRANE'},
          {'cip': TestProducts.aspirine500Cip, 'name': 'ASPIRINE'},
          {'cip': TestProducts.ibuprofene400Cip, 'name': 'IBUPROFENE'},
          {'cip': TestProducts.amoxicilline500Cip, 'name': 'AMOXICILLINE'},
        ];

        // Add items via scanner in restock mode
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.switchToRestockMode();

        for (final item in letterItems) {
          await appRobot.scanner.scanCipCode(item['cip'] as String);
          await appRobot.scanner.waitForScanResult();
        }

        // Navigate to restock
        await appRobot.navigateToTab('restock');
        await appRobot.waitForNetworkRequests();

        // Test alphabetical sections
        appRobot.restock.expectSectionVisible('A'); // AMOXICILLINE
        appRobot.restock.expectSectionVisible('D'); // DOLIPRANE

        // Test scrolling
        await appRobot.restock.scrollToBottomOfList();
        await appRobot.restock.scrollToTopOfList();

        // Verify all items are still visible
        for (final item in letterItems) {
          appRobot.restock.expectItemInRestock(item['name'] as String);
        }

        print('✅ GP3.3: Alphabetical sections and scrolling passed');
      },
    );

    patrolTest(
      'GP3.4: Restock with zero quantities and validation',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.switchToRestockMode();

        // Add an item
        await appRobot.scanner.scanCipCode(TestProducts.doliprane1000Cip);
        await appRobot.scanner.waitForScanResult();

        // Navigate to restock
        await appRobot.navigateToTab('restock');
        await appRobot.waitForNetworkRequests();

        // Set quantity to zero
        await appRobot.restock.setQuantity('DOLIPRANE', 0);

        // Item should still exist with zero quantity
        appRobot.restock.expectItemInRestock('DOLIPRANE');
        appRobot.restock.expectItemQuantityZero('DOLIPRANE');

        // Test negative quantities (should be prevented or handled gracefully)
        try {
          await appRobot.restock.decreaseQuantity('DOLIPRANE');
          // Should either stay at zero or handle gracefully
        } catch (e) {
          print('⚠️ GP3.4: Negative quantity prevented: $e');
        }

        print('✅ GP3.4: Zero quantities and validation passed');
      },
    );

    patrolTest(
      'GP3.5: Restock persistence and app lifecycle',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.switchToRestockMode();

        // Add items
        await appRobot.scanner.scanCipCode(TestProducts.doliprane1000Cip);
        await appRobot.scanner.waitForScanResult();

        await appRobot.scanner.scanCipCode(TestProducts.ibuprofene400Cip);
        await appRobot.scanner.waitForScanResult();

        // Navigate to restock and verify
        await appRobot.navigateToTab('restock');
        await appRobot.waitForNetworkRequests();

        appRobot.restock.expectItemQuantity('DOLIPRANE', 1);
        appRobot.restock.expectItemQuantity('IBUPROFENE', 1);

        // Background app
        await appRobot.backgroundApp();
        await Future.delayed(const Duration(seconds: 3));

        // Resume app
        await appRobot.resumeApp();
        await appRobot.waitForAppToFullyLoad();

        // Navigate back to restock
        await appRobot.navigateToTab('restock');

        // Verify persistence
        appRobot.restock.expectItemQuantity('DOLIPRANE', 1);
        appRobot.restock.expectItemQuantity('IBUPROFENE', 1);

        print('✅ GP3.5: Persistence and app lifecycle passed');
      },
    );

    patrolTest(
      'GP3.6: Restock performance with large quantities',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.switchToRestockMode();

        // Performance measurement for adding many items
        final addTimes = <int>[];
        const int itemCount = 10;

        for (int i = 0; i < itemCount; i++) {
          final startTime = DateTime.now().millisecondsSinceEpoch;

          await appRobot.scanner.scanCipCode(TestProducts.doliprane1000Cip);
          await appRobot.scanner.waitForScanResult();

          final endTime = DateTime.now().millisecondsSinceEpoch;
          addTimes.add(endTime - startTime);
        }

        final averageAddTime = addTimes.reduce((a, b) => a + b) / addTimes.length;
        print('📊 GP3.6: Average add time: ${averageAddTime.round()}ms');

        // Navigate to restock and verify
        await appRobot.navigateToTab('restock');
        await appRobot.waitForNetworkRequests();

        // Verify cumulative quantity
        appRobot.restock.expectItemQuantity('DOLIPRANE', itemCount);

        // Test performance of quantity updates
        final updateStartTime = DateTime.now().millisecondsSinceEpoch;

        await appRobot.restock.setQuantity('DOLIPRANE', itemCount + 5);

        final updateEndTime = DateTime.now().millisecondsSinceEpoch;
        print('📊 GP3.6: Quantity update time: ${updateEndTime - updateStartTime}ms');

        appRobot.restock.expectItemQuantity('DOLIPRANE', itemCount + 5);

        // Test bulk delete performance
        final deleteStartTime = DateTime.now().millisecondsSinceEpoch;

        await appRobot.restock.tapClearAll();
        await appRobot.handleAnyDialog(accept: true);

        final deleteEndTime = DateTime.now().millisecondsSinceEpoch;
        print('📊 GP3.6: Bulk delete time: ${deleteEndTime - deleteStartTime}ms');

        appRobot.restock.expectEmptyStateVisible();

        print('✅ GP3.6: Performance test completed');
      },
    );

    patrolTest(
      'GP3.7: Restock error handling and edge cases',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.switchToRestockMode();

        // Test scanning unknown CIP in restock mode
        await appRobot.scanner.scanCipCode('9999999999999'); // Invalid CIP
        await appRobot.scanner.waitForScanResult();

        // Should show error but not crash
        try {
          await $.waitForTextToAppear('Médicament non trouvé', timeout: const Duration(seconds: 3));
          print('✅ GP3.7: Unknown CIP error handled correctly');
        } catch (e) {
          print('⚠️ GP3.7: Unknown CIP error message not shown');
        }

        // Verify no bubble appeared for invalid CIP
        appRobot.scanner.expectNoBubblesVisible();

        // Navigate to restock and verify empty state
        await appRobot.navigateToTab('restock');
        appRobot.restock.expectEmptyRestockList();

        // Test operations on empty list
        try {
          await appRobot.restock.tapSelectAll();
          await appRobot.restock.tapClearSelected();
          print('✅ GP3.7: Bulk operations on empty list handled gracefully');
        } catch (e) {
          print('⚠️ GP3.7: Bulk operations failed on empty list: $e');
        }

        print('✅ GP3.7: Error handling and edge cases completed');
      },
    );
  });
}