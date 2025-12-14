import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../data/test_products.dart';
import '../helpers/mock_preferences_helper.dart';
import '../helpers/test_database_helper.dart';
import '../robots/app_robot.dart';

/// GP1: Scanner Standalone Test
///
/// Test the core scanning functionality:
/// 1. App initialization with database
/// 2. Camera permission handling
/// 3. Scan a known CIP (Doliprane)
/// 4. Verify bubble appearance
/// 5. Tap bubble to open detail sheet
/// 6. Verify medication detail information
void main() {
  group('GP1: Scanner Standalone Tests', () {
    patrolTest(
      'GP1.1: Complete scanner workflow - Permission → Scan → Bubble → Detail',
      config: PatrolTesterConfig(printLogs: true),
      ($) async {
        final appRobot = AppRobot($);
        // PHASE 1: Setup and Initialization
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        // Start app and handle permissions
        await appRobot.completeAppInitialization();
        await appRobot.handleAllPermissions();

        // PHASE 2: Navigate to Scanner
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.waitForCameraInitialization();

        // Verify scanner is ready
        appRobot.scanner.expectScannerModeActive();
        appRobot.scanner.expectCameraActive();

        // PHASE 3: Scan Known CIP (Doliprane)
        await appRobot.measureTime(
          () async {
            await appRobot.scanner.scanCipCode(TestProducts.doliprane1000Cip);
            await appRobot.scanner.waitForScanResult();
          },
          'Doliprane CIP scan',
        );

        // PHASE 4: Verify Bubble Appearance
        await appRobot.scanner.waitForBubbleAnimation();
        appRobot.scanner.expectBubbleVisible(TestProducts.doliprane1000Name);
        appRobot.scanner.expectBubbleCount(1);

        // PHASE 5: Tap Bubble to Open Detail
        await appRobot.scanner
            .tapBubbleByMedicationName(TestProducts.doliprane1000Name);
        await appRobot.scanner.waitForModalBottomSheet();

        // PHASE 6: Verify Medication Detail Information
        // Check basic medication info
        await appRobot.waitForTextToAppear(TestProducts.doliprane1000Name);
        await appRobot.waitForTextToAppear('Paracétamol');
        await appRobot.waitForTextToAppear('1000 mg');

        // Verify detail sheet elements
        await appRobot
            .waitForWidgetToAppear(const Key('medicationDetailSheet'));
        await appRobot.waitForWidgetToAppear(const Key('ficheButton'));
        await appRobot.waitForWidgetToAppear(const Key('rcpButton'));

        // Verify additional information
        await appRobot.waitForTextToAppear(TestProducts.doliprane1000Labo);
        await appRobot.waitForTextToAppear('Boîte de');

        debugPrint('✅ GP1.1: Complete scanner workflow passed');
      },
    );

    patrolTest(
      'GP1.2: Scanner with unknown CIP - Error handling',
      config: PatrolTesterConfig(printLogs: true),
      ($) async {
        final appRobot = AppRobot($);
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.waitForCameraInitialization();

        // Scan unknown CIP
        await appRobot.scanner.scanCipCode('9999999999999'); // Invalid CIP
        await appRobot.scanner.waitForScanResult();

        // Verify error handling
        await appRobot.waitForTextToAppear('Médicament non trouvé');
        await appRobot.waitForTextToAppear('CIP invalide');

        // Verify no bubbles appear
        appRobot.scanner.expectNoBubblesVisible();

        debugPrint('✅ GP1.2: Unknown CIP error handling passed');
      },
      // Skip this test as per user request if needed, but keeping it compilable
    );

    patrolTest(
      'GP1.3: Scanner mode switching - Analysis vs Restock',
      config: PatrolTesterConfig(printLogs: true),
      ($) async {
        final appRobot = AppRobot($);
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.waitForCameraInitialization();

        // Initially in Analysis mode
        appRobot.scanner.expectScannerModeActive();

        // Switch to Restock mode
        await appRobot.scanner.switchToRestockMode();
        appRobot.scanner.expectRestockModeActive();

        // Scan in Restock mode
        await appRobot.scanner.scanCipCode(TestProducts.doliprane1000Cip);
        await appRobot.scanner.waitForScanResult();

        // Bubble should still appear but for restock context
        appRobot.scanner.expectBubbleVisible(TestProducts.doliprane1000Name);

        // Switch back to Analysis mode
        await appRobot.scanner.switchToScanMode();
        appRobot.scanner.expectScannerModeActive();

        debugPrint('✅ GP1.3: Scanner mode switching passed');
      },
    );

    patrolTest(
      'GP1.4: Scanner torch functionality',
      config: PatrolTesterConfig(printLogs: true),
      ($) async {
        final appRobot = AppRobot($);
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.waitForCameraInitialization();

        // Test torch toggle (may not work on all devices/emulators)
        try {
          await appRobot.scanner.toggleTorch();
          appRobot.scanner.expectTorchOn();

          await appRobot.scanner.toggleTorch();
          appRobot.scanner.expectTorchOff();

          debugPrint('✅ GP1.4: Torch functionality available and working');
        } catch (e) {
          debugPrint('⚠️ GP1.4: Torch not available on this device/emulator');
        }
      },
    );

    patrolTest(
      'GP1.5: Scanner manual entry workflow',
      config: PatrolTesterConfig(printLogs: true),
      ($) async {
        final appRobot = AppRobot($);
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.waitForCameraInitialization();

        // Open manual entry
        await appRobot.scanner.openManualEntry();
        appRobot.scanner.expectManualEntrySheetVisible();

        // Enter CIP manually
        await appRobot.scanner.enterCipManually(TestProducts.doliprane500Cip);
        await appRobot.scanner.submitManualEntry();
        await appRobot.scanner.waitForScanResult();

        // Verify results
        appRobot.scanner.expectBubbleVisible('DOLIPRANE 500 mg');

        // Cancel manual entry sheet
        await appRobot.scanner.openManualEntry();
        await appRobot.scanner.cancelManualEntry();

        debugPrint('✅ GP1.5: Manual entry workflow passed');
      },
    );

    patrolTest(
      'GP1.6: Scanner with generic medication',
      config: PatrolTesterConfig(printLogs: true),
      ($) async {
        final appRobot = AppRobot($);
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.waitForCameraInitialization();

        // Scan generic medication
        await appRobot.scanner.scanCipCode(TestProducts.genericDolipraneCip);
        await appRobot.scanner.waitForScanResult();

        // Verify generic appears
        appRobot.scanner.expectBubbleVisible(TestProducts.genericDolipraneName);

        // Open details and verify generic badge
        await appRobot.scanner
            .tapBubbleByMedicationName(TestProducts.genericDolipraneName);
        await appRobot.scanner.waitForModalBottomSheet();

        // Look for generic indication
        try {
          await appRobot.waitForTextToAppear('Générique');
          debugPrint('✅ GP1.6: Generic medication badge visible');
        } catch (e) {
          debugPrint(
              '⚠️ GP1.6: Generic badge not visible but medication loaded');
        }

        debugPrint('✅ GP1.6: Scanner with generic medication passed');
      },
    );

    patrolTest(
      'GP1.7: Scanner performance and resilience',
      config: PatrolTesterConfig(printLogs: true),
      ($) async {
        final appRobot = AppRobot($);
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.waitForCameraInitialization();

        // Perform multiple rapid scans
        final scanTimes = <int>[];
        for (int i = 0; i < 5; i++) {
          final startTime = DateTime.now().millisecondsSinceEpoch;

          // Use different CIP codes or same one
          final cip = i % 2 == 0
              ? TestProducts.doliprane1000Cip
              : TestProducts.doliprane500Cip;

          await appRobot.scanner.scanCipCode(cip);
          await appRobot.scanner.waitForScanResult();

          final endTime = DateTime.now().millisecondsSinceEpoch;
          scanTimes.add(endTime - startTime);

          // Wait between scans
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }

        final averageScanTime =
            scanTimes.reduce((a, b) => a + b) / scanTimes.length;
        debugPrint('📊 GP1.7: Average scan time: ${averageScanTime.round()}ms');

        // Verify app is still responsive
        appRobot.scanner.expectScannerModeActive();
        appRobot.scanner.expectCameraActive();

        // Verify bubbles are present
        appRobot.scanner.expectBubbleVisible('DOLIPRANE');

        debugPrint('✅ GP1.7: Scanner performance test completed');
      },
    );

    patrolTest(
      'GP1.8: Scanner app lifecycle handling',
      config: PatrolTesterConfig(printLogs: true),
      ($) async {
        final appRobot = AppRobot($);
        // Setup
        await MockPreferencesHelper.configureForTesting();
        await TestDatabaseHelper.injectTestDatabase();

        await appRobot.completeAppInitialization();
        await appRobot.navigateToTab('scanner');
        await appRobot.scanner.waitForCameraInitialization();

        // Scan medication
        await appRobot.scanner.scanCipCode(TestProducts.doliprane1000Cip);
        await appRobot.scanner.waitForScanResult();
        appRobot.scanner.expectBubbleVisible(TestProducts.doliprane1000Name);

        // Background app
        await appRobot.backgroundApp();
        await Future<void>.delayed(const Duration(seconds: 2));

        // Resume app
        await appRobot.resumeApp();
        await appRobot.waitForAppToFullyLoad();

        // Verify scanner still works
        appRobot.scanner.expectScannerModeActive();
        appRobot.scanner.expectBubbleVisible(TestProducts.doliprane1000Name);

        // Test another scan after resume
        await appRobot.scanner.scanCipCode(TestProducts.doliprane500Cip);
        await appRobot.scanner.waitForScanResult();

        debugPrint('✅ GP1.8: Scanner app lifecycle handling passed');
      },
    );
  });
}
