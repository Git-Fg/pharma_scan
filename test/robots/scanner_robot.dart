import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_card.dart';

/// WHY: Encapsulates scanner UI interactions so integration tests remain readable
/// and resilient to layout changes. Follows the Robot Pattern for test maintainability.
class ScannerRobot {
  ScannerRobot(this.tester);

  final WidgetTester tester;

  /// WHY: Verify that the camera is active by checking for MobileScanner widget
  /// or the "ready to scan" state indicator.
  Future<void> verifyCameraActive() async {
    await tester.pumpAndSettle();
    // Check for MobileScanner widget or the ready state text
    final hasScanner = find.byType(MobileScanner).evaluate().isNotEmpty;
    final hasReadyText = find.text(Strings.readyToScan).evaluate().isNotEmpty;
    expect(
      hasScanner || hasReadyText,
      isTrue,
      reason: 'Camera should be active or ready to scan',
    );
  }

  /// WHY: Verify that a scan result bubble is displayed with the given medication name.
  /// Uses ProductCard which replaces all previous bubble types.
  Future<void> verifyScanResult(String name) async {
    await tester.pumpAndSettle();
    // Check for ProductCard widget
    final hasProductCard = find.byType(ProductCard).evaluate().isNotEmpty;
    expect(
      hasProductCard,
      isTrue,
      reason: 'Scan result ProductCard should be displayed',
    );

    // Verify the medication name appears in the card
    expect(find.text(name), findsAtLeastNWidgets(1));
  }

  /// WHY: Tap the manual entry button using semantic label for robustness.
  Future<void> tapManualEntry() async {
    await tester.tap(find.bySemanticsLabel(Strings.manuallyEnterCipCode));
    await tester.pumpAndSettle();
  }

  /// WHY: Tap the gallery import button using semantic label for robustness.
  Future<void> tapGalleryImport() async {
    await tester.tap(find.bySemanticsLabel(Strings.importBarcodeFromGallery));
    await tester.pumpAndSettle();
  }
}
