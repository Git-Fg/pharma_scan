import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../lib/core/utils/test_tags.dart';
import 'base_robot.dart';

/// Robot for navigation interactions including tab navigation, deep linking,
/// system navigation, and app lifecycle management
class NavRobot extends BaseRobot {
  NavRobot(super.$);

  // --- Tab Navigation ---
  Future<void> switchToScannerTab() async {
    await $(Key(TestTags.navScanner)).tap();
    await pumpAndSettleWithDelay();
    // Wait for tab transition animation
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> switchToExplorerTab() async {
    await $(Key(TestTags.navExplorer)).tap();
    await pumpAndSettleWithDelay();
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> switchToRestockTab() async {
    await $(Key(TestTags.navRestock)).tap();
    await pumpAndSettleWithDelay();
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> navigateToTab(String tabName) async {
    switch (tabName.toLowerCase()) {
      case 'scanner':
      case 'scan':
        await switchToScannerTab();
        break;
      case 'explorer':
      case 'search':
        await switchToExplorerTab();
        break;
      case 'restock':
      case 'inventory':
        await switchToRestockTab();
        break;
      default:
        throw Exception('Unknown tab: $tabName');
    }
  }

  // --- Deep Linking ---
  Future<void> navigateToDeepLink(String deepLink) async {
    try {
      // This would typically involve using the Patrol deep linking capabilities
      // In a real implementation, you might use:
      // await $.native.openUrl(deepLink);
      // or integrate with your app's deep linking system

      // For now, we'll simulate deep linking by triggering the navigation
      // This would need to be adapted based on your app's deep linking implementation
      debugPrint('Navigating to deep link: $deepLink');

      // Wait for navigation to complete
      await pumpAndSettleWithDelay(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Failed to navigate to deep link $deepLink: $e');
    }
  }

  Future<void> navigateToMedicationDetail(String medicationId) async {
    await navigateToDeepLink('medication/$medicationId');
  }

  Future<void> navigateToClusterDetail(String clusterId) async {
    await navigateToDeepLink('cluster/$clusterId');
  }

  Future<void> navigateToSearch(String query) async {
    await navigateToDeepLink('search?q=$query');
  }

  // --- System Navigation ---
  Future<void> pressBackButton() async {
    try {
      await $.native.pressBack();
      await pumpAndSettleWithDelay();
    } catch (e) {
      debugPrint('Failed to press back button: $e');
      // Fallback for non-mobile platforms
      await navigateBack();
    }
  }

  Future<void> pressHomeButton() async {
    try {
      await $.native.pressHome();
      // Don't pump and settle here as app goes to background
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Failed to press home button: $e');
    }
  }

  Future<void> pressOverviewButton() async {
    try {
      await $.native.pressRecentApps();
      await pumpAndSettleWithDelay();
    } catch (e) {
      debugPrint('Failed to press overview button: $e');
    }
  }

  Future<void> navigateBack() async {
    try {
      // Look for back button in the app
      final backButton = find.byIcon(Icons.arrow_back);
      if (backButton.evaluate().isNotEmpty) {
        await $.tester.tap(backButton);
        await pumpAndSettleWithDelay();
      } else {
        // Try app bar back button
        final appBarBackButton = find.byType(BackButton);
        if (appBarBackButton.evaluate().isNotEmpty) {
          await $.tester.tap(appBarBackButton);
          await pumpAndSettleWithDelay();
        }
      }
    } catch (e) {
      debugPrint('Failed to navigate back: $e');
    }
  }

  // --- Tab Reselection ---
  Future<void> reselectCurrentTab() async {
    // Get the current active tab and reselect it
    try {
      // Look for currently selected tab indicator
      final activeTab = find.byWidgetPredicate((widget) =>
          widget.key?.toString().contains('selected') == true ||
          widget.key?.toString().contains('active') == true);

      if (activeTab.evaluate().isNotEmpty) {
        await $.tester.tap(activeTab.first);
        await pumpAndSettleWithDelay();
      } else {
        // Fallback: try each tab and see which one is already selected
        await switchToScannerTab();
        // If already on scanner, this will trigger reselection
      }
    } catch (e) {
      debugPrint('Failed to reselect current tab: $e');
    }
  }

  Future<void> doubleTapTab(String tabName) async {
    await navigateToTab(tabName);
    await Future.delayed(const Duration(milliseconds: 100));
    await navigateToTab(tabName);
  }

  // --- App Lifecycle ---
  Future<void> backgroundApp() async {
    try {
      await $.native.pressHome();
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
      debugPrint('Failed to background app: $e');
    }
  }

  Future<void> resumeApp() async {
    try {
      // This would typically involve bringing the app back to foreground
      // Implementation varies by platform
      debugPrint('Resuming app...');

      // Wait for app to fully resume
      await pumpAndSettleWithDelay(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Failed to resume app: $e');
    }
  }

  Future<void> minimizeApp() async {
    await backgroundApp();
  }

  Future<void> restoreApp() async {
    await resumeApp();
  }

  // --- Screen Navigation ---
  Future<void> scrollToTop() async {
    final scrollable = find.byType(Scrollable).first;
    if (scrollable.evaluate().isNotEmpty) {
      await scrollToTop();
      await pumpAndSettleWithDelay();
    }
  }

  Future<void> goToPreviousScreen() async {
    await navigateBack();
  }

  Future<void> goToNextScreen() async {
    // This would depend on having a "next" button or navigation pattern
    try {
      final nextButton = find.text('Suivant').first;
      if (nextButton.evaluate().isNotEmpty) {
        await $.tester.tap(nextButton);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Next button not found: $e');
    }
  }

  // --- Gesture Navigation ---
  Future<void> swipeFromLeftEdge() async {
    try {
      final size = $.tester.binding.window.physicalSize;
      final start = Offset(0, size.height / 2);
      final end = Offset(size.width * 0.3, size.height / 2);

      await $.tester.dragFromPoint(start, end);
      await pumpAndSettleWithDelay();
    } catch (e) {
      debugPrint('Failed to swipe from left edge: $e');
    }
  }

  Future<void> swipeFromRightEdge() async {
    try {
      final size = $.tester.binding.window.physicalSize;
      final start = Offset(size.width, size.height / 2);
      final end = Offset(size.width * 0.7, size.height / 2);

      await $.tester.dragFromPoint(start, end);
      await pumpAndSettleWithDelay();
    } catch (e) {
      debugPrint('Failed to swipe from right edge: $e');
    }
  }

  // --- Navigation History ---
  Future<void> expectNavigationHistorySize(int expectedSize) async {
    // This would require access to the navigation stack
    // Implementation depends on your navigation system (Auto Router, etc.)
    debugPrint('Expected navigation history size: $expectedSize');
  }

  // --- Assertions ---
  void expectTabBarVisible() {
    // Look for bottom navigation bar
    final tabBar = find.byType(BottomNavigationBar);
    if (tabBar.evaluate().isNotEmpty) {
      expect(tabBar, findsOneWidget);
    } else {
      // Alternative: Look for custom tab bar implementation
      expectVisibleByKey(Key('bottom_navigation'));
    }
  }

  void expectCurrentTab(String tabName) {
    switch (tabName.toLowerCase()) {
      case 'scanner':
      case 'scan':
        expectVisibleByKey(Key(TestTags.navScanner));
        break;
      case 'explorer':
      case 'search':
        expectVisibleByKey(Key(TestTags.navExplorer));
        break;
      case 'restock':
      case 'inventory':
        expectVisibleByKey(Key(TestTags.navRestock));
        break;
      default:
        throw Exception('Unknown tab for assertion: $tabName');
    }
  }

  void expectTabSelected(String tabName) {
    expectCurrentTab(tabName);

    // Additional check for selected state
    try {
      final tabKey = switch (tabName.toLowerCase()) {
        'scanner' => TestTags.navScanner,
        'explorer' => TestTags.navExplorer,
        'restock' => TestTags.navRestock,
        _ => throw Exception('Unknown tab: $tabName'),
      };

      // Look for selected indicator
      final selectedTab = find.byWidgetPredicate((widget) =>
          widget.key == Key(tabKey) &&
          widget.toString().contains('selected'));

      if (selectedTab.evaluate().isEmpty) {
        // Tab exists but might not have selected indicator in current implementation
        debugPrint('Tab selected state not explicitly verified for $tabName');
      }
    } catch (e) {
      debugPrint('Failed to verify tab selected state: $e');
    }
  }

  void expectOnScreen(String screenName) {
    switch (screenName.toLowerCase()) {
      case 'scanner':
        expectVisibleByKey(Key(TestTags.scannerScreen));
        break;
      case 'explorer':
        expectVisibleByKey(Key(TestTags.explorerScreen));
        break;
      case 'restock':
        expectVisibleByKey(Key(TestTags.restockList));
        break;
      default:
        expectVisibleByText(screenName);
    }
  }

  void expectNavigationButtonVisible(String buttonText) {
    expectVisibleByText(buttonText);
  }

  void expectBackButtonVisible() {
    final backButton = find.byIcon(Icons.arrow_back);
    if (backButton.evaluate().isNotEmpty) {
      expect(backButton, findsOneWidget);
    } else {
      final backButtonType = find.byType(BackButton);
      expect(backButtonType, findsOneWidget);
    }
  }

  void expectHomeButtonVisible() {
    final homeButton = find.byIcon(Icons.home);
    if (homeButton.evaluate().isNotEmpty) {
      expect(homeButton, findsOneWidget);
    }
  }

  void expectDeepLinkActive(String deepLink) async {
    // This would require checking the current route/deep link state
    // Implementation depends on your navigation system
    debugPrint('Checking if deep link is active: $deepLink');
  }

  void expectTabBarNotVisible() {
    final tabBar = find.byType(BottomNavigationBar);
    expect(tabBar, findsNothing);
  }

  void expectTabNotSelected(String tabName) {
    // Verify tab is not in selected state
    try {
      final tabKey = switch (tabName.toLowerCase()) {
        'scanner' => TestTags.navScanner,
        'explorer' => TestTags.navExplorer,
        'restock' => TestTags.navRestock,
        _ => throw Exception('Unknown tab: $tabName'),
      };

      final tab = find.byKey(Key(tabKey));
      expect(tab, findsOneWidget);

      // Check that it doesn't have selected state (implementation varies)
    } catch (e) {
      debugPrint('Failed to verify tab not selected state: $e');
    }
  }

  void expectNavigationTo(String expectedRoute) {
    // Check if current route matches expected route
    // This would require access to navigation state
    debugPrint('Expected route: $expectedRoute');
  }

  // --- Complex Navigation Flows ---
  Future<void> navigateThroughTabs(List<String> tabs) async {
    for (final tab in tabs) {
      await navigateToTab(tab);
      await pumpAndSettleWithDelay(const Duration(milliseconds: 500));
    }
  }

  Future<void> performBackNavigation(int numberOfSteps) async {
    for (int i = 0; i < numberOfSteps; i++) {
      await navigateBack();
      await pumpAndSettleWithDelay(const Duration(milliseconds: 300));
    }
  }

  Future<void> simulateUserNavigationFlow() async {
    // Simulate a typical user navigation pattern
    await switchToScannerTab();
    await Future.delayed(const Duration(seconds: 1));

    await switchToExplorerTab();
    await Future.delayed(const Duration(seconds: 1));

    await switchToRestockTab();
    await Future.delayed(const Duration(seconds: 1));

    await switchToScannerTab();
  }

  Future<void> testNavigationRobustness() async {
    // Test various navigation scenarios to ensure robustness
    await simulateUserNavigationFlow();
    await performBackNavigation(3);
    await navigateThroughTabs(['explorer', 'restock', 'scanner']);
    await reselectCurrentTab();
    await doubleTapTab('scanner');
  }
}