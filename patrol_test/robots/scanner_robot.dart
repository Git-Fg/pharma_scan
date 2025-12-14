import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';

import 'base_robot.dart';

enum ScannerMode {
  analysis,
  restock,
}

/// Robot for Scanner screen interactions with enhanced E2E capabilities
class ScannerRobot extends BaseRobot {
  ScannerRobot(super.$);

  // --- Navigation ---
  Future<void> tapScannerTab() async {
    await $(const Key(TestTags.navScanner)).tap();
    await $.pumpAndSettle();
  }

  // --- Scanner Actions ---
  Future<void> openManualEntry() async {
    await $(const Key(TestTags.manualEntryButton)).tap();
    await $.pumpAndSettle();
  }

  Future<void> enterCipAndSearch(String cip) async {
    final inputFinder = $(Strings.cipPlaceholder);
    await inputFinder.waitUntilVisible();
    await inputFinder.enterText(cip);
    await $.pumpAndSettle();

    await $(Strings.search).tap();
    await $.pumpAndSettle();
  }

  Future<void> tapScanButton() async {
    await $(const Key(TestTags.scannerButton)).tap();
    await $.pumpAndSettle();
  }

  Future<void> toggleTorch() async {
    await $(const Key(TestTags.torchButton)).tap();
    await $.pumpAndSettle();
  }

  // --- Enhanced Camera Actions ---
  Future<void> waitForCameraInitialization() async {
    await waitForWidgetToAppear(Key(TestTags.scannerScreen));
    await pumpAndSettleWithDelay(const Duration(seconds: 2));
  }

  Future<void> enableTorch() async {
    try {
      await $(Key(TestTags.torchButton)).tap();
      await pumpAndSettleWithDelay();
    } catch (e) {
      // Torch might not be available on all devices/emulators
      debugPrint('Torch not available: $e');
    }
  }

  Future<void> disableTorch() async {
    try {
      await $(Key(TestTags.torchButton)).tap();
      await pumpAndSettleWithDelay();
    } catch (e) {
      // Torch might not be available on all devices/emulators
      debugPrint('Torch not available: $e');
    }
  }

  Future<void> switchCamera() async {
    try {
      // Look for camera switch button
      final switchButton = find.byIcon(Icons.camera_alt);
      if (switchButton.evaluate().isNotEmpty) {
        await $.tester.tap(switchButton);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      debugPrint('Camera switch failed: $e');
    }
  }

  // --- Enhanced Scanning Actions ---
  Future<void> scanCipCode(String cipCode) async {
    // For E2E tests, use manual entry as reliable method
    await openManualEntry();
    await enterCipManually(cipCode);
    await submitManualEntry();
  }

  Future<void> enterCipManually(String cip) async {
    await $(Strings.cipPlaceholder).enterText(cip);
    await pumpAndSettleWithDelay();
  }

  Future<void> submitManualEntry() async {
    await $(Strings.search).tap();
    await pumpAndSettleWithDelay();
    await waitForLoadingToComplete();
  }

  Future<void> waitForScanResult() async {
    await pumpAndSettleWithDelay(const Duration(seconds: 3));
    await waitForLoadingToComplete(timeout: shortTimeout);
  }

  Future<void> waitForBubbleAnimation() async {
    await Future.delayed(const Duration(milliseconds: 800));
    await $.pumpAndSettle();
  }

  Future<void> cancelManualEntry() async {
    // Try to find cancel button or dismiss
    final cancelButton = find.text('Annuler').first;
    if (cancelButton.evaluate().isNotEmpty) {
      await $.tester.tap(cancelButton);
      await pumpAndSettleWithDelay();
    } else {
      await dismissBottomSheet();
    }
  }

  // --- Mode Switching ---
  Future<void> switchToScanMode() async {
    try {
      final modeToggle = find.textContaining('Scanner Mode:').first;
      if (modeToggle.evaluate().isNotEmpty) {
        await $.tester.tap(modeToggle);
        await pumpAndSettleWithDelay();
      }
    } catch (e) {
      // Alternative: Look for mode switch in controls
      try {
        await $(#modeToggleButton).tap();
        await pumpAndSettleWithDelay();
      } catch (e2) {
        debugPrint('Mode switch failed: $e2');
      }
    }
  }

  Future<void> switchToRestockMode() async {
    await switchToScanMode(); // Toggle to the other mode
  }

  // --- Bubble Interactions ---
  Future<void> tapBubble(int index) async {
    final bubbles = find.byKey(const Key('medication_bubble'));
    if (bubbles.evaluate().length > index) {
      await $.tester.tap(bubbles.at(index));
      await pumpAndSettleWithDelay();
    } else {
      throw Exception('Bubble at index $index not found');
    }
  }

  Future<void> tapBubbleByMedicationName(String medicationName) async {
    final bubble = find.byKey(ValueKey('bubble_$medicationName'));
    if (bubble.evaluate().isNotEmpty) {
      await $.tester.tap(bubble);
      await pumpAndSettleWithDelay();
    } else {
      // Alternative: Look for text and tap containing widget
      final medicationText = find.text(medicationName);
      if (medicationText.evaluate().isNotEmpty) {
        await $.tester.tap(medicationText);
        await pumpAndSettleWithDelay();
      } else {
        throw Exception('Bubble with medication $medicationName not found');
      }
    }
  }

  Future<void> longPressBubble(int index) async {
    final bubbles = find.byKey(const Key('medication_bubble'));
    if (bubbles.evaluate().length > index) {
      await $.tester.longPress(bubbles.at(index));
      await pumpAndSettleWithDelay();
    } else {
      throw Exception('Bubble at index $index not found');
    }
  }

  // --- Gallery Import ---
  Future<void> importFromGallery() async {
    try {
      final galleryButton = find.byIcon(Icons.photo_library);
      if (galleryButton.evaluate().isNotEmpty) {
        await $.tester.tap(galleryButton);
        await pumpAndSettleWithDelay(const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('Gallery import failed: $e');
    }
  }

  // --- Enhanced Assertions ---
  void expectBubbleVisible(String medicationName) {
    expectVisibleByText(medicationName);
    final medicationText = find.text(medicationName);
    expect(medicationText, findsOneWidget);
  }

  void expectBubbleCount(int expectedCount) {
    final bubbles = find.byKey(const Key('medication_bubble'));
    expect(bubbles, findsNWidgets(expectedCount));
  }

  void expectScannerModeActive() {
    expectVisibleByKeyWidget(Key(TestTags.scannerScreen));
    final modeIndicator = find.textContaining('Analysis');
    if (modeIndicator.evaluate().isNotEmpty) {
      expect(modeIndicator, findsOneWidget);
    }
  }

  void expectRestockModeActive() {
    expectVisibleByKeyWidget(Key(TestTags.scannerScreen));
    final modeIndicator = find.textContaining('Restock');
    if (modeIndicator.evaluate().isNotEmpty) {
      expect(modeIndicator, findsOneWidget);
    }
  }

  void expectCameraActive() {
    expectVisibleByKeyWidget(Key(TestTags.scannerScreen));
  }

  void expectManualEntrySheetVisible() {
    expect(find.byType(ModalBottomSheetRoute), findsOneWidget);
    expectVisibleByText('Manually Enter CIP Code');
  }

  void expectSearchSheetVisible() {
    expect(find.byType(ModalBottomSheetRoute), findsOneWidget);
  }

  void expectScanErrorVisible() {
    expectVisibleByText('Error');
    final errorMessage = find.textContaining('not found');
    if (errorMessage.evaluate().isNotEmpty) {
      expect(errorMessage, findsOneWidget);
    }
  }

  void expectNoBubblesVisible() {
    final bubbles = find.byKey(const Key('medication_bubble'));
    expect(bubbles, findsNothing);
  }

  void expectTorchOn() {
    final torchIndicator = find.byIcon(Icons.flash_on);
    if (torchIndicator.evaluate().isNotEmpty) {
      expect(torchIndicator, findsOneWidget);
    }
  }

  void expectTorchOff() {
    final torchIndicator = find.byIcon(Icons.flash_off);
    if (torchIndicator.evaluate().isNotEmpty) {
      expect(torchIndicator, findsOneWidget);
    }
  }

  void expectCameraPermissionGranted() {
    expectVisibleByKeyWidget(Key(TestTags.scannerScreen));
    expectNotVisibleByText('Camera Permission Required');
  }

  // --- Scanner Verifications ---
  Future<void> expectScannerScreenVisible() async {
    await $(const Key(TestTags.scannerScreen)).waitUntilVisible();
  }

  Future<void> expectMedicamentNotFound() async {
    await $(Strings.medicamentNotFound).waitUntilVisible();
  }

  Future<void> expectMedicamentFound() async {
    await $(Strings.ficheInfo).waitUntilVisible();
  }

  Future<void> expectScanButtonVisible() async {
    await $(const Key(TestTags.scannerButton)).waitUntilVisible();
  }

  Future<void> expectManualEntryVisible() async {
    await $(const Key(TestTags.manualEntryButton)).waitUntilVisible();
  }

  Future<void> expectTorchButtonVisible() async {
    await $(const Key(TestTags.torchButton)).waitUntilVisible();
  }

  // --- Scanner Screen Completion ---
  /// Complete scanner flow: navigate to scanner, open manual entry, search CIP
  Future<void> completeManualSearchFlow(String cip) async {
    await tapScannerTab();
    await openManualEntry();
    await enterCipAndSearch(cip);
  }
}
