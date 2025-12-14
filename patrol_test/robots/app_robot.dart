import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pharma_scan/core/utils/strings.dart';

import 'base_robot.dart';
import 'scanner_robot.dart';
import 'explorer_robot.dart';
import 'restock_robot.dart';
import 'nav_robot.dart';

/// Enhanced App Robot that orchestrates screen-specific robots
/// Following the Page Object Model pattern for maintainable E2E tests
class AppRobot extends BaseRobot {
  late final ScannerRobot scanner;
  late final ExplorerRobot explorer;
  late final RestockRobot restock;
  late final NavRobot nav;

  AppRobot(super.$) {
    scanner = ScannerRobot($);
    explorer = ExplorerRobot($);
    restock = RestockRobot($);
    nav = NavRobot($);
  }

  // --- App Lifecycle ---
  Future<void> startApp() async {
    await $.pump();
    await $.pumpAndSettle();
  }

  Future<void> handlePermissions() async {
    // Patrol 4.0: use $.platform.mobile instead of $.native
    if (await $.platform.mobile.isPermissionDialogVisible()) {
      await $.platform.mobile.grantPermissionWhenInUse();
    }
  }

  // --- App Navigation ---
  Future<void> navigateToTab(String tabName) async {
    switch (tabName.toLowerCase()) {
      case 'scanner':
        await scanner.tapScannerTab();
        break;
      case 'explorer':
        await explorer.tapExplorerTab();
        break;
      case 'restock':
        await restock.tapRestockTab();
        break;
      default:
        throw ArgumentError('Unknown tab: $tabName');
    }
  }

  // --- App-wide Actions ---
  Future<void> goBack() async {
    await nav.pressBackButton();
  }

  Future<void> pressHome() async {
    await $.platform.mobile.pressHome();
    await $.pumpAndSettle();
  }

  Future<void> waitAndSettle([Duration? duration]) async {
    if (duration != null) {
      await Future.delayed(duration);
    }
    await $.pumpAndSettle();
  }

  // --- App-wide Verifications ---
  Future<void> expectAppStarted() async {
    // Wait for the app to be fully loaded
    await waitAndSettle(const Duration(seconds: 3));

    // Check that we can see one of the main navigation elements
    await $(#main_scaffold).waitUntilVisible();
  }

  Future<void> expectTabVisible(String tabName) async {
    switch (tabName.toLowerCase()) {
      case 'scanner':
        await scanner.expectScannerScreenVisible();
        break;
      case 'explorer':
        await explorer.expectExplorerScreenVisible();
        break;
      case 'restock':
        await restock.expectRestockScreenVisible();
        break;
      default:
        throw ArgumentError('Unknown tab: $tabName');
    }
  }

  // --- Multi-screen Workflows ---
  /// Complete app initialization flow: start app, handle permissions, verify app loaded
  Future<void> completeAppInitialization() async {
    await startApp();
    await handlePermissions();
    await expectAppStarted();
  }

  /// Navigate through all tabs to verify they're accessible
  Future<void> verifyAllTabsAccessible() async {
    await navigateToTab('scanner');
    await expectTabVisible('scanner');

    await navigateToTab('explorer');
    await expectTabVisible('explorer');

    await navigateToTab('restock');
    await expectTabVisible('restock');
  }

  /// Search for a medication across scanner and explorer
  Future<void> searchMedicationAcrossApp(
      String cip, String medicationName) async {
    // Search via scanner manual entry
    await scanner.completeManualSearchFlow(cip);
    await waitAndSettle();

    // Navigate to explorer and search by name
    await explorer.completeSearchFlow(medicationName);
    await waitAndSettle();
  }

  // --- Enhanced Permission Handling ---
  Future<void> handleAllPermissions() async {
    try {
      // Handle camera permission
      if (await $.platform.mobile.isPermissionDialogVisible()) {
        await $.platform.mobile.grantPermissionWhenInUse();
        await pumpAndSettleWithDelay();
      }

      // Handle storage permission (if needed)
      if (await $.platform.mobile.isPermissionDialogVisible()) {
        await $.platform.mobile.grantPermissionWhenInUse();
        await pumpAndSettleWithDelay();
      }

      // Handle location permission (if needed)
      if (await $.platform.mobile.isPermissionDialogVisible()) {
        await $.platform.mobile.grantPermissionWhenInUse();
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Permission handling failed: $e');
    }
  }

  Future<bool> isPermissionDialogVisible() async {
    try {
      return await $.platform.mobile.isPermissionDialogVisible();
    } catch (e) {
      debugPrint('Failed to check permission dialog visibility: $e');
      return false;
    }
  }

  // --- Enhanced App Lifecycle ---
  Future<void> waitForAppToFullyLoad({Duration? timeout}) async {
    await waitForAppToLoad();
    // Additional wait for any initialization processes
    await Future.delayed(timeout ?? const Duration(seconds: 2));
    await $.pumpAndSettle();
  }

  Future<void> backgroundApp() async {
    await nav.backgroundApp();
  }

  Future<void> resumeApp() async {
    await nav.resumeApp();
  }

  Future<void> minimizeAndRestoreApp() async {
    await backgroundApp();
    await Future.delayed(const Duration(seconds: 2));
    await resumeApp();
  }

  // --- Enhanced Navigation ---
  Future<void> navigateToTabEnhanced(String tabName) async {
    await nav.navigateToTab(tabName);
  }

  Future<void> navigateBack() async {
    await nav.navigateBack();
  }

  Future<void> openDrawer() async {
    try {
      final drawerButton = find.byIcon(Icons.menu);
      if (drawerButton.evaluate().isNotEmpty) {
        await $.tester.tap(drawerButton);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Failed to open drawer: $e');
    }
  }

  // --- Common Actions ---
  Future<void> tapByKey(String key) async {
    await $(Key(key)).tap();
    await pumpAndSettleWithDelay();
  }

  Future<void> enterTextByKey(String key, String text) async {
    await $(Key(key)).enterText(text);
    await pumpAndSettleWithDelay();
  }

  Future<void> waitForSnackBarMessage(String message) async {
    await waitForSnackBar(message);
  }

  // --- Enhanced App Initialization ---
  Future<void> completeAppInitializationEnhanced() async {
    await startApp();
    await handleAllPermissions();
    await waitForAppToFullyLoad();
  }

  Future<void> completeAppInitializationWithoutPermissions() async {
    await startApp();
    await waitForAppToFullyLoad();
  }

  // --- Enhanced Multi-Screen Workflows ---
  Future<void> performCompleteAppTour() async {
    // Start with scanner
    await navigateToTab('scanner');
    await pumpAndSettleWithDelay(const Duration(seconds: 1));

    // Move to explorer
    await navigateToTab('explorer');
    await pumpAndSettleWithDelay(const Duration(seconds: 1));

    // Move to restock
    await navigateToTab('restock');
    await pumpAndSettleWithDelay(const Duration(seconds: 1));

    // Return to scanner
    await navigateToTab('scanner');
  }

  Future<void> performCriticalUserJourney() async {
    // 1. Scan a medication
    await navigateToTab('scanner');
    await scanner.openManualEntry();
    await scanner.enterCipManually('3400934168322'); // Doliprane
    await scanner.submitManualEntry();

    // 2. Search in explorer
    await navigateToTab('explorer');
    await explorer.enterSearchQuery('Doliprane');
    await explorer.submitSearch();

    // 3. Add to restock
    await navigateToTab('scanner');
    await scanner.switchToRestockMode();
    await scanner.scanCipCode('3400934168322');

    // 4. Verify in restock
    await navigateToTab('restock');
    await restock.expectItemInRestock('DOLIPRANE');
  }

  Future<void> testAppResilience() async {
    await performCompleteAppTour();

    // Background and restore app
    await minimizeAndRestoreApp();

    // Verify app is still functional
    await performCompleteAppTour();

    // Test rapid navigation
    for (int i = 0; i < 5; i++) {
      await navigateToTab('scanner');
      await navigateToTab('explorer');
      await navigateToTab('restock');
    }
  }

  // --- Enhanced App State Management ---
  Future<void> clearAppData() async {
    try {
      // This would depend on your app's data clearing mechanism
      // Could involve navigating to settings and clearing data
      debugPrint('Clearing app data...');
    } catch (e) {
      debugPrint('Failed to clear app data: $e');
    }
  }

  Future<void> resetAppToInitialState() async {
    await clearAppData();
    await startApp();
    await handleAllPermissions();
    await waitForAppToFullyLoad();
  }

  // --- Enhanced Error Handling ---
  Future<void> handleUnexpectedDialogs() async {
    try {
      // Look for any unexpected dialogs and handle them
      while (find.byType(Dialog).evaluate().isNotEmpty) {
        final dialog = find.byType(Dialog).first;
        final okButton = find.descendant(
          of: dialog,
          matching: find.text('OK'),
        );

        if (okButton.evaluate().isNotEmpty) {
          await $.tester.tap(okButton);
        } else {
          // Try to find any button in the dialog
          final anyButton = find.descendant(
            of: dialog,
            matching: find.byType(ElevatedButton),
          );
          if (anyButton.evaluate().isNotEmpty) {
            await $.tester.tap(anyButton.first);
          } else {
            break; // Can't handle this dialog
          }
        }
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Failed to handle unexpected dialogs: $e');
    }
  }

  Future<void> handleNetworkErrors() async {
    try {
      // Look for network error indicators
      final networkError = find.textContaining('Erreur réseau');
      if (networkError.evaluate().isNotEmpty) {
        // Try to retry button if present
        final retryButton = find.text('Réessayer');
        if (retryButton.evaluate().isNotEmpty) {
          await $.tester.tap(retryButton);
          await pumpAndSettleWithDelay();
        }
      }
    } catch (e) {
      debugPrint('Failed to handle network errors: $e');
    }
  }

  // --- Enhanced App Verifications ---
  Future<void> expectAppFullyLoaded() async {
    await expectAppStarted();

    // Verify all main navigation elements are present
    nav.expectTabBarVisible();

    // Verify no loading indicators are present
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  }

  Future<void> expectAppStateConsistent() async {
    // Check that app is in a consistent state
    await expectAppFullyLoaded();

    // Verify no unexpected dialogs are showing
    expect(find.byType(Dialog), findsNothing);

    // Verify no error messages are showing
    expect(find.textContaining('Erreur'), findsNothing);
  }

  Future<void> expectAllTabsAccessible() async {
    await verifyAllTabsAccessible();

    // Additional checks for tab functionality
    nav.expectTabBarVisible();
    nav.expectCurrentTab('scanner');
  }

  Future<void> expectNoUnexpectedStates() async {
    await handleUnexpectedDialogs();
    await handleNetworkErrors();
    await expectAppStateConsistent();
  }

  // --- Performance and Stress Testing ---
  Future<void> performRapidNavigationTest() async {
    final startTime = DateTime.now();

    for (int i = 0; i < 20; i++) {
      await navigateToTab('scanner');
      await navigateToTab('explorer');
      await navigateToTab('restock');
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    debugPrint('Rapid navigation test completed in: $duration');

    // Verify app is still responsive
    await expectAppStateConsistent();
  }

  Future<void> performMemoryStressTest() async {
    // Navigate through many screens to test memory usage
    for (int i = 0; i < 10; i++) {
      await performCriticalUserJourney();
      await handleUnexpectedDialogs();
    }

    await expectAppStateConsistent();
  }

  // --- Integration with Other Robots ---
  Future<void> performCrossRobotWorkflow() async {
    // 1. Use NavRobot for navigation
    await nav.navigateThroughTabs(['scanner', 'explorer', 'restock']);

    // 2. Use ScannerRobot for scanning
    await scanner.switchToScanMode();
    await scanner.scanCipCode('3400934168322');

    // 3. Use ExplorerRobot for searching
    await explorer.enterSearchQuery('Amoxicilline');
    await explorer.submitSearch();

    // 4. Use RestockRobot for inventory management
    await restock.tapRestockTab();
    await restock.pullToRefresh();

    // 5. Verify everything is working
    await expectAppStateConsistent();
  }
}
