import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/services/haptic_service.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';
import 'package:pharma_scan/features/restock/presentation/providers/restock_provider.dart';
import 'package:pharma_scan/features/restock/presentation/screens/restock_screen.dart';
import 'package:pharma_scan/features/restock/presentation/widgets/restock_list_item.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRestockNotifier extends RestockNotifier {
  @override
  Stream<List<RestockItemEntity>> build() =>
      Stream<List<RestockItemEntity>>.value(const []);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Restock list interactions', () {
    testWidgets('tapping checkbox toggles item', (tester) async {
      final item = RestockItemEntity(
        cip: Cip13.validated('3400934056781'),
        label: 'Item 1',
        quantity: 1,
        isChecked: false,
        isPrinceps: true,
      );

      var toggled = false;
      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: RestockListItem(
                item: item,
                showPrincepsSubtitle: false,
                haptics: const HapticService(enabled: false),
                onIncrement: () {},
                onDecrement: () {},
                onAddTen: () {},
                onSetQuantity: (_) {},
                onToggleChecked: () {
                  toggled = true;
                },
                onDismissed: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ShadCheckbox));
      await tester.pumpAndSettle();

      expect(toggled, isTrue);
    });

    testWidgets('swipe delete triggers mutation', (tester) async {
      final item = RestockItemEntity(
        cip: Cip13.validated('3400934056782'),
        label: 'Item 2',
        quantity: 1,
        isChecked: false,
        isPrinceps: false,
      );

      var dismissed = false;
      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: RestockListItem(
                item: item,
                showPrincepsSubtitle: false,
                haptics: const HapticService(enabled: false),
                onIncrement: () {},
                onDecrement: () {},
                onAddTen: () {},
                onSetQuantity: (_) {},
                onToggleChecked: () {},
                onDismissed: (_) {
                  dismissed = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dismissible = find.byType(Dismissible);
      await tester.drag(dismissible, const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    });

    testWidgets('empty state shows localized message', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final preferencesService = PreferencesService(prefs);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            restockProvider.overrideWith(_FakeRestockNotifier.new),
            sortingPreferenceProvider.overrideWith(
              (ref) => SortingPreference.princeps,
            ),
            preferencesServiceProvider.overrideWithValue(preferencesService),
          ],
          child: const ShadApp(
            home: RestockScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(Strings.restockEmptyTitle), findsOneWidget);
      expect(find.text(Strings.restockOpenScanner), findsOneWidget);
      expect(find.text(Strings.restockEmpty), findsOneWidget);
    });
  });
}
