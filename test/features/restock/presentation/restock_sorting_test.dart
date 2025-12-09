import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';
import 'package:pharma_scan/features/restock/presentation/providers/restock_provider.dart';

void main() {
  RestockItemEntity item({
    required String label,
    String? princeps,
    String? form,
    int quantity = 1,
    bool isChecked = false,
    bool isPrinceps = false,
  }) => RestockItemEntity(
    cip: Cip13.validated('3400000000000'),
    label: label,
    princepsLabel: princeps,
    form: form,
    quantity: quantity,
    isChecked: isChecked,
    isPrinceps: isPrinceps,
  );

  group('Restock sorting', () {
    test('sorts by form then label with fallback', () {
      final items = [
        item(label: 'B', form: 'Sirop'),
        item(label: 'A', form: 'Comprimé'),
        item(label: 'C'),
      ];

      final sorted = sortRestockItemsForTest(items, SortingPreference.form);

      // Keys: AUTRES, COMPRIMÉ, SIROP
      expect(sorted[0].form, null);
      expect(sorted[1].form, 'Comprimé');
      expect(sorted[2].form, 'Sirop');
    });

    test('groups by form name uppercase, unknown to AUTRES', () {
      final items = [
        item(label: 'B', form: 'Sirop'),
        item(label: 'A', form: 'Comprimé'),
        item(label: 'C'),
      ];

      final grouped = groupRestockItemsForTest(items, SortingPreference.form);

      expect(
        grouped.keys,
        containsAll(['SIROP', 'COMPRIMÉ', Strings.restockFormUnknown]),
      );
      expect(grouped['SIROP']!.single.label, 'B');
      expect(grouped[Strings.restockFormUnknown]!.single.label, 'C');
    });
  });
}
