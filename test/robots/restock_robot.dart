import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/features/restock/presentation/screens/restock_screen.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RestockRobot {
  final WidgetTester tester;
  RestockRobot(this.tester);

  // Locators
  Finder get clearAllButton => find.byKey(const ValueKey('clear_all_button'));
  Finder get _clearButton => clearAllButton; // Deprecated, use clearAllButton
  Finder get _confirmDialogButton => find
      .byType(ShadButton)
      .last; // Le dernier bouton ShadButton est le bouton de confirmation
  Finder get _cancelDialogButton => find
      .byType(ShadButton)
      .first; // Le premier bouton ShadButton est le bouton d'annulation
  Finder get _emptyStateText => find.text('Aucune boîte à ranger');

  // Setup
  Future<void> pumpScreen({List<dynamic> overrides = const []}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: const ShadApp(home: RestockScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Actions
  Future<void> tapClearAll() async {
    await tester.tap(_clearButton);
    await tester.pumpAndSettle();
  }

  Future<void> tapClearChecked() async {
    // Trouver l'icône de coche qui correspond à "clear checked"
    final clearCheckedButton =
        find.byKey(const ValueKey('clear_checked_button'));
    await tester.tap(clearCheckedButton);
    await tester.pumpAndSettle();
  }

  Future<void> confirmDialog() async {
    // Attendre que le dialogue apparaisse
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(_confirmDialogButton);
    await tester.pumpAndSettle();
  }

  Future<void> cancelDialog() async {
    // Attendre que le dialogue apparaisse
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(_cancelDialogButton);
    await tester.pumpAndSettle();
  }

  // Assertions
  void expectEmptyStateVisible() {
    expect(_emptyStateText, findsOneWidget);
  }

  void expectItemVisible(String itemName) {
    expect(find.text(itemName), findsOneWidget);
  }

  bool hasDialog() {
    return tester.any(find.byType(ShadDialog));
  }
}
