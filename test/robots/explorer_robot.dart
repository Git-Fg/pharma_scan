import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_card.dart';

/// WHY: Encapsulates explorer UI interactions so widget tests remain readable
/// and resilient to layout changes.
class ExplorerRobot {
  ExplorerRobot(this.tester);

  final WidgetTester tester;

  Future<void> searchFor(String query) async {
    final searchField = find.bySemanticsLabel(Strings.searchLabel);
    if (searchField.evaluate().isEmpty) {
      await _waitUntilVisible(searchField);
    }
    await tester.tap(searchField);
    await tester.enterText(searchField, query);
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
  }

  Future<void> tapResult(String name) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  Future<void> clearSearch() async {
    // WHY: Target by accessibility label defined in Strings for robustness
    await tester.tap(find.bySemanticsLabel(Strings.clearSearch));
    await tester.pumpAndSettle();
  }

  Future<void> openFilterSheet() async {
    // WHY: Robust targeting even if icon changes
    await tester.tap(find.bySemanticsLabel(Strings.openFilters));
    await tester.pumpAndSettle();
  }

  void expectNoResults() {
    expect(find.text(Strings.noResults), findsOneWidget);
  }

  void expectResultCount(int count) {
    expect(find.byType(ProductCard), findsNWidgets(count));
  }

  Future<void> _waitUntilVisible(Finder finder) async {
    final stopwatch = Stopwatch()..start();
    while (finder.evaluate().isEmpty) {
      if (stopwatch.elapsed > const Duration(seconds: 5)) {
        fail('Timed out waiting for element matching predicate');
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}
