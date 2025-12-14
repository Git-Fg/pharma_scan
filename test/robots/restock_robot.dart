import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/providers/app_bar_provider.dart';

import 'package:pharma_scan/features/restock/presentation/screens/restock_screen.dart';
import 'package:shadcn_ui/shadcn_ui.dart';


/// Test wrapper that simulates the app shell with AppBar.
///
/// This is necessary because RestockScreen uses `useAppHeader` hook
/// which sets header config via provider. The actual AppBar is rendered
/// by the parent shell, not RestockScreen itself.
class _TestShell extends ConsumerWidget {
  const _TestShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appBarConfig = ref.watch(appBarStateProvider);
    return Scaffold(
      appBar: appBarConfig.isVisible
          ? AppBar(
              title: appBarConfig.title,
              actions: appBarConfig.actions,
            )
          : null,
      body: child,
    );
  }
}

class RestockRobot {
  final WidgetTester tester;
  RestockRobot(this.tester);

  // Locators
  Finder get clearAllButton => find.byIcon(LucideIcons.trash2);
  Finder get clearCheckedButton => find.byIcon(LucideIcons.check);
  Finder get _confirmDialogButton => find
      .byType(ShadButton)
      .last; // Le dernier bouton ShadButton est le bouton de confirmation
  Finder get _cancelDialogButton => find
      .byType(ShadButton)
      .first; // Le premier bouton ShadButton est le bouton d'annulation
  Finder get _emptyStateText => find.text('Aucune boîte à ranger');

  /// Sets up the test environment with the restock screen.
  ///
  /// [overrides] - Optional list of provider overrides to add.
  /// These are typically created with `.overrideWith()` or `.overrideWithValue()`.
  Future<void> pumpScreen({List<dynamic> overrides = const []}) async {
    // Set up mock preferences for testing
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final preferencesService = PreferencesService(prefs);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesServiceProvider.overrideWithValue(preferencesService),
          // Spread additional overrides - Dart infers the type from context
          for (final o in overrides) o,
        ],
        child: const ShadApp(
          home: _TestShell(
            child: RestockScreen(),
          ),
        ),
      ),
    );

    // Wait for async useEffect in useAppHeader to fire
    // Use pump with duration instead of pumpAndSettle to avoid timeout
    // on async providers that may have continuous reloading
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Actions
  Future<void> tapClearAll() async {
    await tester.tap(clearAllButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> tapClearChecked() async {
    await tester.tap(clearCheckedButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> confirmDialog() async {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(_confirmDialogButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> cancelDialog() async {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(_cancelDialogButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
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
