// test/features/scanner/scanner_layout_safety_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/adaptive_bottom_panel.dart';
import 'package:pharma_scan/features/scanner/presentation/screens/camera_screen.dart';
import 'package:pharma_scan/features/scanner/presentation/widgets/scanner_controls.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../test_utils.dart';

/// Layout safety tests for `CameraScreen` to ensure UI resilience.
void main() {
  group('Scanner Layout Safety - Screen Size & Overflow Resilience', () {
    // WHY: Set up providers with mocked initialization to avoid real database operations
    setUp(() {
      // Ensure initialization is ready for tests
      // This will be handled by the ProviderScope in pumpApp
    });

    testWidgets(
      'displays gallery and manual entry buttons when camera is inactive',
      (tester) async {
        await tester.pumpApp(const CameraScreen());
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(Strings.importBarcodeFromGallery),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(Strings.manuallyEnterCipCode),
          findsOneWidget,
        );

        // AND: Torch button should NOT be visible when camera is inactive
        final torchButton = find.descendant(
          of: find.byType(CameraScreen),
          matching: find.byIcon(LucideIcons.zap),
        );
        expect(torchButton, findsNothing);
      },
    );

    testWidgets(
      'torch button is not in the bottom panel with gallery and manual entry buttons',
      (tester) async {
        await tester.pumpApp(const CameraScreen());
        await tester.pumpAndSettle();

        final bottomPanel = find.byType(AdaptiveBottomPanel);
        expect(bottomPanel, findsOneWidget);

        // AND: Verify gallery and manual entry buttons are in the bottom panel
        final galleryButton = find.descendant(
          of: bottomPanel,
          matching: find.bySemanticsLabel(Strings.importBarcodeFromGallery),
        );
        final manualButton = find.descendant(
          of: bottomPanel,
          matching: find.bySemanticsLabel(Strings.manuallyEnterCipCode),
        );

        expect(galleryButton, findsOneWidget);
        expect(manualButton, findsOneWidget);

        // AND: Torch button should NOT be in the bottom panel
        // We verify this by checking that no torch icon exists as a descendant
        // of the bottom panel's Row containing the buttons
        final bottomPanelRow = find.descendant(
          of: bottomPanel,
          matching: find.byType(Row),
        );
        final torchInRow = find.descendant(
          of: bottomPanelRow,
          matching: find.byIcon(LucideIcons.zap),
        );
        expect(torchInRow, findsNothing);
      },
    );

    testWidgets('bottom panel buttons do not overflow on small screens', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpApp(const CameraScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // AND: All buttons should still be visible
      expect(
        find.bySemanticsLabel(Strings.importBarcodeFromGallery),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(Strings.manuallyEnterCipCode),
        findsOneWidget,
      );
    });

    testWidgets('bottom panel buttons do not overflow on medium screens', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(375, 667));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpApp(const CameraScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // AND: All buttons should be visible
      expect(
        find.bySemanticsLabel(Strings.importBarcodeFromGallery),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(Strings.manuallyEnterCipCode),
        findsOneWidget,
      );
    });

    testWidgets('bottom panel buttons do not overflow on large screens', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpApp(const CameraScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // AND: All buttons should be visible
      expect(
        find.bySemanticsLabel(Strings.importBarcodeFromGallery),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(Strings.manuallyEnterCipCode),
        findsOneWidget,
      );
    });

    testWidgets('button texts have overflow protection', (tester) async {
      await tester.pumpApp(const CameraScreen());
      await tester.pumpAndSettle();

      final galleryButtonText = find.descendant(
        of: find.bySemanticsLabel(Strings.importBarcodeFromGallery),
        matching: find.byType(Text),
      );
      expect(galleryButtonText, findsOneWidget);

      final galleryTextWidget = tester.widget<Text>(galleryButtonText);
      expect(galleryTextWidget.overflow, TextOverflow.ellipsis);
      expect(galleryTextWidget.maxLines, 1);

      // AND: Find manual entry button text and verify it has overflow protection
      final manualButtonText = find.descendant(
        of: find.bySemanticsLabel(Strings.manuallyEnterCipCode),
        matching: find.byType(Text),
      );
      expect(manualButtonText, findsOneWidget);

      final manualTextWidget = tester.widget<Text>(manualButtonText);
      expect(manualTextWidget.overflow, TextOverflow.ellipsis);
      expect(manualTextWidget.maxLines, 1);
    });

    testWidgets('scanner controls are accessible via test tags', (
      tester,
    ) async {
      await tester.pumpApp(const CameraScreen());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key(TestTags.scanGalleryBtn)), findsOneWidget);
      expect(find.byKey(const Key(TestTags.scanManualBtn)), findsOneWidget);
    });

    group('Torch Button Logic', () {
      testWidgets(
        'torch button visibility is conditionally rendered based on camera state',
        (tester) async {
          await tester.pumpApp(const CameraScreen());
          await tester.pumpAndSettle();

          final torchIconAnywhere = find.byIcon(LucideIcons.zap);
          expect(torchIconAnywhere, findsNothing);

          // Testing the active state would require mocking the camera state,
          // which is complex due to MobileScanner dependencies; this test
          // verifies the initial state where torch should be hidden.
        },
      );

      testWidgets('torch button is not in bottom panel structure', (
        tester,
      ) async {
        await tester.pumpApp(const CameraScreen());
        await tester.pumpAndSettle();

        final scannerControls = find.byType(ScannerControls);
        expect(scannerControls, findsOneWidget);

        // AND: Find the bottom panel inside ScannerControls
        final bottomPanel = find.descendant(
          of: scannerControls,
          matching: find.byType(AdaptiveBottomPanel),
        );
        expect(bottomPanel, findsOneWidget);

        final torchInBottomPanel = find.descendant(
          of: bottomPanel,
          matching: find.byIcon(LucideIcons.zap),
        );
        expect(torchInBottomPanel, findsNothing);

        // AND: Verify torch button exists but is separate from bottom panel
        // (It's in a Positioned widget in CameraScreen's Stack, not in ScannerControls)
        // This test verifies the torch is NOT in the bottom panel structure
      });
    });
  });
}
