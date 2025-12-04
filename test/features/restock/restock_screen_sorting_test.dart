import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';
import 'package:pharma_scan/features/restock/presentation/providers/restock_provider.dart';
import 'package:pharma_scan/features/restock/presentation/screens/restock_screen.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  group('RestockScreen sorting & grouping', () {
    Future<void> pumpRestockScreen(
      WidgetTester tester, {
      required List<RestockItemEntity> items,
      required SortingPreference preference,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            restockListProvider.overrideWith(
              (ref) => Stream<List<RestockItemEntity>>.value(items),
            ),
            sortingPreferenceProvider.overrideWith(
              (ref) => Stream<SortingPreference>.value(preference),
            ),
          ],
          child: ShadApp.custom(
            theme: ShadThemeData(
              brightness: Brightness.light,
              colorScheme: const ShadSlateColorScheme.light(),
            ),
            darkTheme: ShadThemeData(
              brightness: Brightness.dark,
              colorScheme: const ShadSlateColorScheme.dark(),
            ),
            appBuilder: (context) => MaterialApp(
              builder: (context, child) =>
                  ShadAppBuilder(child: child ?? const SizedBox.shrink()),
              home: const RestockScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    RestockItemEntity buildItem({
      required String cip,
      required String label,
      String? princepsLabel,
    }) {
      return RestockItemEntity(
        cip: Cip13.validated(cip),
        label: label,
        princepsLabel: princepsLabel,
        quantity: 1,
        isChecked: false,
        isPrinceps: false,
      );
    }

    testWidgets('groups by product name when sorting by generic name', (
      tester,
    ) async {
      final items = [
        buildItem(
          cip: '3400934056781',
          label: 'Amoxicilline Biogaran',
          princepsLabel: 'CLAMOXYL',
        ),
        buildItem(
          cip: '3400934056782',
          label: 'Doliprane 1000mg',
          princepsLabel: 'DOLIPRANE',
        ),
      ];

      await pumpRestockScreen(
        tester,
        items: items,
        preference: SortingPreference.generic,
      );

      // Headers should be A then D (by product name)
      final headerA = find.text('A');
      final headerD = find.text('D');

      expect(headerA, findsOneWidget);
      expect(headerD, findsOneWidget);
    });

    testWidgets('groups by princeps name when sorting by princeps', (
      tester,
    ) async {
      final items = [
        buildItem(
          cip: '3400934056781',
          label: 'Amoxicilline Biogaran',
          princepsLabel: 'CLAMOXYL',
        ),
        buildItem(
          cip: '3400934056782',
          label: 'Doliprane 1000mg',
          princepsLabel: 'ASPEGIC',
        ),
      ];

      await pumpRestockScreen(
        tester,
        items: items,
        preference: SortingPreference.princeps,
      );

      // Headers should be A then C (by princeps name)
      final headerA = find.text('A');
      final headerC = find.text('C');

      expect(headerA, findsOneWidget);
      expect(headerC, findsOneWidget);

      // And subtitle uses "Ranger avec : [Princeps]"
      expect(
        find.text(Strings.restockSubtitlePrinceps('CLAMOXYL')),
        findsOneWidget,
      );
      expect(
        find.text(Strings.restockSubtitlePrinceps('ASPEGIC')),
        findsOneWidget,
      );
    });
  });
}
