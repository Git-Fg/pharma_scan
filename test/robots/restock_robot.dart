import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/features/restock/presentation/widgets/restock_list_item.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RestockRobot {
  RestockRobot(this.tester);

  final WidgetTester tester;

  void expectItemCount(int count) {
    expect(find.byType(RestockListItem), findsNWidgets(count));
  }

  Future<void> tapIncrement(String label) async {
    final item = _findItemByLabel(label);
    final buttons = find.descendant(
      of: item,
      matching: find.byType(ShadButton),
    );
    expect(buttons, findsAtLeastNWidgets(2));
    await tester.tap(buttons.last);
    await tester.pumpAndSettle();
  }

  Future<void> tapDecrement(String label) async {
    final item = _findItemByLabel(label);
    final buttons = find.descendant(
      of: item,
      matching: find.byType(ShadButton),
    );
    expect(buttons, findsAtLeastNWidgets(2));
    await tester.tap(buttons.first);
    await tester.pumpAndSettle();
  }

  Future<void> toggleCheckbox(String label) async {
    final item = _findItemByLabel(label);
    final checkbox = find.descendant(
      of: item,
      matching: find.byType(ShadCheckbox),
    );
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
  }

  void expectTotalChecked(int count) {
    final items = find.byType(RestockListItem);
    var checkedCount = 0;
    for (final item in items.evaluate()) {
      final widget = item.widget;
      if (widget is RestockListItem && widget.item.isChecked) {
        checkedCount++;
      }
    }
    expect(checkedCount, equals(count));
  }

  void expectQuantity(String label, int expectedQuantity) {
    final item = _findItemByLabel(label);
    expect(
      find.descendant(
        of: item,
        matching: find.text(expectedQuantity.toString()),
      ),
      findsOneWidget,
    );
  }

  Finder _findItemByLabel(String label) {
    return find
        .descendant(
          of: find.byType(RestockListItem),
          matching: find.text(label),
        )
        .first;
  }
}
