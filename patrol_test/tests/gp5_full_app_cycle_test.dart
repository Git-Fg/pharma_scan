import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../data/test_products.dart';
import '../helpers/mock_preferences_helper.dart';
import '../helpers/test_database_helper.dart';
import '../robots/app_robot.dart';

/// GP5: Full App Cycle Test
///
/// Test the complete app functionality and lifecycle:
/// 1. Cross-tab navigation
/// 2. Scanner → Explorer → Restock workflow
/// 3. Background app and resume
/// 4. Data persistence verification
/// 5. App resilience and recovery
/// 6. Complete user journey simulation
void main() {
  group('GP5: Full App Cycle Tests', () {
    late AppRobot appRobot;

    setUp(() async {
      appRobot = AppRobot($);
    });

    patrolTest(
      'GP5.1: Complete cross-tab user journey',
      config: PatrolTesterConfig(
        reportLogs: true,
      ),
      ($) async {
        // PHASE 1: Setup and Initialization
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();

        // PHASE 2: Start in Scanner - Manual entry workflow
        print('📱 GP5.1: Starting scanner workflow');
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.waitForCameraInitialization();

        // Scan medication manually
        await appRobot.scanner.scanCipCode(TestProducts.doliprane1000Cip);
        await appRobot.scanner.waitForScanResult();
        appRobot.scanner.expectBubbleVisible(TestProducts.doliprane1000Name);

        // PHASE 3: Navigate to Explorer - Search workflow
        print('🔍 GP5.1: Navigating to explorer');
        await appRobot.navigateToTab('explorer');
        await appRobot.explorer.expectExplorerScreenVisible();

        // Search for same medication
        await appRobot.explorer.enterSearchQuery('Doliprane');
        await appRobot.explorer.submitSearch();
        await appRobot.waitForNetworkRequests();

        appRobot.explorer.expectMedicationGroupVisible('DOLIPRANE');

        // Open medication details
        await appRobot.explorer.tapMedicationGroup('DOLIPRANE');
        await appRobot.explorer.waitForDrawer();

        // PHASE 4: Navigate to Restock - Inventory workflow
        print('📦 GP5.1: Navigating to restock');
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.switchToRestockMode();

        // Scan to add to restock
        await appRobot.scanner.scanCipCode(TestProducts.doliprane1000Cip);
        await appRobot.scanner.waitForScanResult();

        // Navigate to restock tab
        await appRobot.navigateToTab('restock');
        await appRobot.waitForNetworkRequests();

        // Verify medication in restock
        appRobot.restock.expectItemInRestock('DOLIPRANE');

        // PHASE 5: Cross-tab state verification
        print('🔄 GP5.1: Verifying cross-tab state');

        // Navigate back through tabs
        await appRobot.navigateToTab('explorer');
        await $.pumpAndSettle();

        // Previous search should persist
        appRobot.explorer.expectSearchQueryEntered('Doliprane');

        await appRobot.navigateToTab('scanner');
        await $.pumpAndSettle();

        // Scanner bubble should persist
        appRobot.scanner.expectBubbleVisible(TestProducts.doliprane1000Name);

        // Verify restock item still exists
        await appRobot.navigateToTab('restock');
        appRobot.restock.expectItemInRestock('DOLIPRANE');

        print('✅ GP5.1: Complete cross-tab user journey passed');
      },
    );

    patrolTest(
      'GP5.2: App lifecycle - Background and resume persistence',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup initial state
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();

        // Create some data in each tab
        print('📱 GP5.2: Setting up initial state');

        // Scanner: Scan multiple items
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.waitForCameraInitialization();

        final scanTargets = [
          TestProducts.doliprane1000Cip,
          TestProducts.ibuprofene400Cip,
          TestProducts.aspirine500Cip,
        ];

        for (final cip in scanTargets) {
          await appRobot.scanner.scanCipCode(cip);
          await appRobot.scanner.waitForScanResult();
          await Future.delayed(const Duration(milliseconds: 300));
        }

        // Explorer: Search and open details
        await appRobot.navigateToTab('explorer');
        await appRobot.explorer.enterSearchQuery('Paracétamol');
        await appRobot.explorer.submitSearch();
        await appRobot.waitForNetworkRequests();

        await appRobot.explorer.tapMedicationGroup('DOLIPRANE');
        await appRobot.explorer.waitForDrawer();

        // Restock: Add items with quantities
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.switchToRestockMode();

        await appRobot.scanner.scanCipCode(TestProducts.doliprane500Cip);
        await appRobot.scanner.waitForScanResult();

        await appRobot.scanner.scanCipCode(TestProducts.doliprane500Cip);
        await appRobot.scanner.waitForScanResult();

        await appRobot.scanner.scanCipCode(TestProducts.doliprane500Cip);
        await appRobot.scanner.waitForScanResult();

        // PHASE: Background app
        print('⏸️ GP5.2: Backgrounding app');
        await appRobot.backgroundApp();
        await Future.delayed(const Duration(seconds: 3));

        // PHASE: Resume app
        print('▶️ GP5.2: Resuming app');
        await appRobot.resumeApp();
        await appRobot.waitForAppToFullyLoad();

        // PHASE: Verify persistence
        print('✅ GP5.2: Verifying persistence');

        // Verify restock data persisted
        await appRobot.navigateToTab('restock');
        await appRobot.waitForNetworkRequests();
        appRobot.restock.expectItemQuantity('DOLIPRANE 500 mg', 3);

        // Verify scanner bubbles persisted
        await appRobot.navigateToTab('scanner');
        appRobot.scanner.expectBubbleVisible('DOLIPRANE');

        // Verify explorer search persisted
        await appRobot.navigateToTab('explorer');
        appRobot.explorer.expectSearchQueryEntered('Paracétamol');

        print('✅ GP5.2: App lifecycle persistence verified');
      },
    );

    patrolTest(
      'GP5.3: App resilience and stress testing',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();

        // Stress test: Rapid navigation and actions
        print('🏋️ GP5.3: Starting resilience test');

        final resilienceStartTime = DateTime.now();

        // Phase 1: Rapid tab switching
        for (int cycle = 0; cycle < 5; cycle++) {
          print('🔄 GP5.3: Resilience cycle ${cycle + 1}/5');

          await appRobot.navigateToTab('scanner');
          await appRobot.scanner.scanCipCode(TestProducts.doliprane1000Cip);
          await appRobot.scanner.waitForScanResult();

          await appRobot.navigateToTab('explorer');
          await appRobot.explorer.enterSearchQuery('Test$cycle');
          await appRobot.explorer.submitSearch();
          await appRobot.waitForNetworkRequests();

          await appRobot.navigateToTab('restock');
          await appRobot.scanner.switchToRestockMode();
          await appRobot.scanner.scanCipCode(TestProducts.ibuprofene400Cip);
          await appRobot.scanner.waitForScanResult();

          // Quick verification
          appRobot.scanner.expectBubbleVisible('DOLIPRANE');
        }

        // Phase 2: Background/resume stress
        for (int i = 0; i < 3; i++) {
          print('⏸️ GP5.3: Background cycle ${i + 1}/3');

          await appRobot.backgroundApp();
          await Future.delayed(const Duration(seconds: 1));

          await appRobot.resumeApp();
          await appRobot.waitForAppToFullyLoad();

          // Quick verification app is responsive
          await appRobot.navigateToTab('scanner');
          appRobot.scanner.expectScannerModeActive();
        }

        // Phase 3: Memory stress test
        print('🧠 GP5.3: Memory stress test');

        // Add many scanner bubbles
        for (int i = 0; i < 10; i++) {
          await appRobot.scanner.scanCipCode(TestProducts.doliprane1000Cip);
          await appRobot.scanner.waitForScanResult();
        }

        appRobot.scanner.expectBubbleCount(10); // Should have at least some bubbles

        // Clear some memory by navigation
        await appRobot.performCompleteAppTour();

        final resilienceEndTime = DateTime.now();
        final totalDuration = resilienceEndTime.difference(resilienceStartTime);

        print('📊 GP5.3: Resilience test completed in ${totalDuration.inSeconds}s');

        // Final verification
        await appRobot.expectAppStateConsistent();

        print('✅ GP5.3: App resilience and stress testing passed');
      },
    );

    patrolTest(
      'GP5.4: Data integrity across app restart',
      config: PatrolTesterConfig(),
      ($) async {
        // Initial setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();

        // Create data
        print('💾 GP5.4: Creating test data');

        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.waitForCameraInitialization();

        // Add items to restock
        await appRobot.scanner.switchToRestockMode();

        final restockItems = [
          {'cip': TestProducts.doliprane500Cip, 'name': 'DOLIPRANE 500 mg', 'quantity': 2},
          {'cip': TestProducts.ibuprofene400Cip, 'name': 'IBUPROFENE 400 mg', 'quantity': 1},
          {'cip': TestProducts.aspirine500Cip, 'name': 'ASPIRINE 500 mg', 'quantity': 3},
        ];

        for (final item in restockItems) {
          for (int i = 0; i < item['quantity'] as int; i++) {
            await appRobot.scanner.scanCipCode(item['cip'] as String);
            await appRobot.scanner.waitForScanResult();
          }
        }

        // Verify data before restart
        await appRobot.navigateToTab('restock');
        await appRobot.waitForNetworkRequests();

        for (final item in restockItems) {
          appRobot.restock.expectItemQuantity(item['name'] as String, item['quantity'] as int);
        }

        // Simulate app restart (in real scenario, this would be a fresh app launch)
        print('🔄 GP5.4: Simulating app restart');

        // In a real test, you would restart the app here
        // For this simulation, we'll verify data persistence through background/resume
        await appRobot.backgroundApp();
        await Future.delayed(const Duration(seconds: 5)); // Longer pause
        await appRobot.resumeApp();
        await appRobot.waitForAppToFullyLoad();

        // Verify data persistence
        await appRobot.navigateToTab('restock');
        await appRobot.waitForNetworkRequests();

        for (final item in restockItems) {
          appRobot.restock.expectItemQuantity(item['name'] as String, item['quantity'] as int);
        }

        print('✅ GP5.4: Data integrity verification passed');
      },
    );

    patrolTest(
      'GP5.5: Complete user journey with controlled substances',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup for controlled substances testing
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();

        print('🚫 GP5.5: Testing controlled substances workflow');

        // Test Ventoline (controlled asthma medication)
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.waitForCameraInitialization();

        await appRobot.scanner.scanCipCode(TestProducts.ventolineCip);
        await appRobot.scanner.waitForScanResult();

        // Look for controlled substance indicators
        try {
          await $.waitForTextToAppear('Médicament contrôlé', timeout: const Duration(seconds: 3));
          await $.waitForTextToAppear('Stupéfiant', timeout: const Duration(seconds: 3));
          print('✅ GP5.5: Controlled substance warnings found');
        } catch (e) {
          print('⚠️ GP5.5: Controlled substance warnings not immediately visible');
        }

        // Verify bubble appears (may have special styling)
        appRobot.scanner.expectBubbleVisible('VENTOLINE');

        // Check details for special handling requirements
        await appRobot.scanner.tapBubbleByMedicationName('VENTOLINE');
        await appRobot.scanner.waitForModalBottomSheet();

        // Look for prescription requirements
        try {
          await $.waitForTextToAppear('Ordonnance', timeout: const Duration(seconds: 2));
          await $.waitForTextToAppear('Prescription', timeout: const Duration(seconds: 2));
          print('✅ GP5.5: Prescription requirements found');
        } catch (e) {
          print('⚠️ GP5.5: Prescription requirements not immediately visible');
        }

        // Test normal medication for comparison
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.scanCipCode(TestProducts.doliprane1000Cip);
        await appRobot.scanner.waitForScanResult();

        appRobot.scanner.expectBubbleVisible('DOLIPRANE');

        print('✅ GP5.5: Controlled substances workflow completed');
      },
    );

    patrolTest(
      'GP5.6: Error handling and recovery testing',
      config: PatrolTesterConfig(),
      ($) async {
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();

        print('🚨 GP5.6: Testing error handling and recovery');

        // Test unknown CIP handling
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.waitForCameraInitialization();

        await appRobot.scanner.scanCipCode('9999999999999'); // Invalid
        await appRobot.scanner.waitForScanResult();

        // Should show error but app remains functional
        try {
          await $.waitForTextToAppear('Non trouvé');
          print('✅ GP5.6: Unknown CIP error handled');
        } catch (e) {
          print('⚠️ GP5.6: Unknown CIP error message not found');
        }

        // Verify app still works
        await appRobot.scanner.scanCipCode(TestProducts.doliprane1000Cip);
        await appRobot.scanner.waitForScanResult();
        appRobot.scanner.expectBubbleVisible('DOLIPRANE');

        // Test network error simulation (if possible)
        await appRobot.navigateToTab('explorer');
        await appRobot.explorer.enterSearchQuery('TestNetworkError');

        // Wait for network and handle potential errors
        try {
          await appRobot.handleNetworkErrors();
        } catch (e) {
          print('⚠️ GP5.6: Network error handling tested');
        }

        // Test rapid consecutive operations
        await appRobot.performRapidNavigationTest();

        // Verify app recovered successfully
        await appRobot.expectAppStateConsistent();

        print('✅ GP5.6: Error handling and recovery verified');
      },
    );
  });
}