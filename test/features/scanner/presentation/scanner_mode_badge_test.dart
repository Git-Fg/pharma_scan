import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:pharma_scan/features/scanner/presentation/widgets/scanner_controls.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../helpers/pump_app.dart';

void main() {
  group('ScannerModeToggle', () {
    testWidgets('shows analysis label and toggles on tap', (tester) async {
      var tapped = false;
      await tester.pumpApp(
        ScannerModeToggle(
          mode: ScannerMode.analysis,
          onToggle: () => tapped = true,
        ),
      );

      expect(find.text(Strings.scannerModeAnalysis), findsOneWidget);
      expect(find.byIcon(LucideIcons.scanSearch), findsOneWidget);

      await tester.tap(find.byType(ScannerModeToggle));
      expect(tapped, isTrue);
    });

    testWidgets('shows restock label and icon', (tester) async {
      await tester.pumpApp(
        ScannerModeToggle(
          mode: ScannerMode.restock,
          onToggle: () {},
        ),
      );

      expect(find.text(Strings.scannerModeRestock), findsOneWidget);
      expect(find.byIcon(LucideIcons.box), findsOneWidget);
    });
  });
}
