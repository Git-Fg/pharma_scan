import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/scanner/presentation/widgets/scanner_controls.dart';
import 'base_robot.dart';

/// Robot for Scanner widget interactions.
///
/// Encapsulates finders and actions for scanner-related widgets.
class ScannerRobot extends BaseRobot {
  ScannerRobot(super.tester);

  /// Finds the scanner mode toggle widget.
  Finder get _modeToggle => find.byType(ScannerModeToggle);

  /// Taps the scanner mode toggle.
  Future<void> tapModeToggle() async {
    await tester.tap(_modeToggle);
    await tester.pump();
  }

  /// Verifies the analysis mode label is shown.
  void expectAnalysisMode() {
    expect(find.text(Strings.scannerModeAnalysis), findsOneWidget);
  }

  /// Verifies the restock mode label is shown.
  void expectRestockMode() {
    expect(find.text(Strings.scannerModeRestock), findsOneWidget);
  }
}
