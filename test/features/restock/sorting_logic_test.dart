import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/features/restock/domain/entities/restock_item_entity.dart';

List<RestockItemEntity> _sortItems(
  List<RestockItemEntity> items,
  SortingPreference preference,
) {
  final sorted = [...items];
  int compare(RestockItemEntity a, RestockItemEntity b) {
    String keyFor(RestockItemEntity item) {
      if (preference == SortingPreference.princeps &&
          item.princepsLabel != null &&
          item.princepsLabel!.trim().isNotEmpty) {
        return item.princepsLabel!.trim().toUpperCase();
      }
      return item.label.trim().toUpperCase();
    }

    final ka = keyFor(a);
    final kb = keyFor(b);
    final keyCompare = ka.compareTo(kb);
    if (keyCompare != 0) return keyCompare;
    return a.label.toUpperCase().compareTo(b.label.toUpperCase());
  }

  sorted.sort(compare);
  return sorted;
}

Map<String, List<RestockItemEntity>> _groupByInitial(
  List<RestockItemEntity> items,
  SortingPreference preference,
) {
  final groups = <String, List<RestockItemEntity>>{};

  String letterFor(RestockItemEntity item) {
    final base =
        preference == SortingPreference.princeps &&
            item.princepsLabel != null &&
            item.princepsLabel!.trim().isNotEmpty
        ? item.princepsLabel!
        : item.label;
    final trimmed = base.trim();
    if (trimmed.isEmpty) return '#';
    final first = trimmed[0].toUpperCase();
    final isAlpha = RegExp('[A-ZÀ-ÖØ-Ý]').hasMatch(first);
    return isAlpha ? first : '#';
  }

  for (final item in items) {
    final letter = letterFor(item);
    groups.putIfAbsent(letter, () => []).add(item);
  }

  final sortedKeys = groups.keys.toList()..sort();
  final sortedGroups = <String, List<RestockItemEntity>>{};
  for (final key in sortedKeys) {
    sortedGroups[key] = groups[key]!;
  }
  return sortedGroups;
}

void main() {
  group('Restock Sorting Logic - Drawer Sort vs Name Sort', () {
    test(
      'sort by Generic (alphabetical by label) orders correctly',
      () {
        final items = [
          RestockItemEntity(
            cip: Cip13.validated('3400930302613'),
            label: 'Z-Generic',
            princepsLabel: 'A-Princeps',
            quantity: 1,
            isChecked: false,
            isPrinceps: false,
          ),
          RestockItemEntity(
            cip: Cip13.validated('3400930302614'),
            label: 'A-Generic',
            princepsLabel: 'Z-Princeps',
            quantity: 1,
            isChecked: false,
            isPrinceps: false,
          ),
        ];

        final sorted = _sortItems(items, SortingPreference.generic);

        expect(
          sorted[0].label,
          equals('A-Generic'),
          reason: 'Sort by Generic should order by label alphabetically',
        );
        expect(
          sorted[1].label,
          equals('Z-Generic'),
          reason: 'Sort by Generic should order by label alphabetically',
        );
      },
    );

    test(
      'sort by Princeps (alphabetical by princepsLabel) orders correctly',
      () {
        final items = [
          RestockItemEntity(
            cip: Cip13.validated('3400930302613'),
            label: 'Z-Generic',
            princepsLabel: 'A-Princeps',
            quantity: 1,
            isChecked: false,
            isPrinceps: false,
          ),
          RestockItemEntity(
            cip: Cip13.validated('3400930302614'),
            label: 'A-Generic',
            princepsLabel: 'Z-Princeps',
            quantity: 1,
            isChecked: false,
            isPrinceps: false,
          ),
        ];

        final sorted = _sortItems(items, SortingPreference.princeps);

        expect(
          sorted[0].princepsLabel,
          equals('A-Princeps'),
          reason:
              'Sort by Princeps should order by princepsLabel alphabetically',
        );
        expect(
          sorted[1].princepsLabel,
          equals('Z-Princeps'),
          reason:
              'Sort by Princeps should order by princepsLabel alphabetically',
        );
      },
    );

    test(
      'sort by Princeps falls back to label when princepsLabel is null',
      () {
        final items = [
          RestockItemEntity(
            cip: Cip13.validated('3400930302613'),
            label: 'Z-Standalone',
            princepsLabel: null,
            quantity: 1,
            isChecked: false,
            isPrinceps: true,
          ),
          RestockItemEntity(
            cip: Cip13.validated('3400930302614'),
            label: 'A-Standalone',
            princepsLabel: null,
            quantity: 1,
            isChecked: false,
            isPrinceps: true,
          ),
        ];

        final sorted = _sortItems(items, SortingPreference.princeps);

        expect(
          sorted[0].label,
          equals('A-Standalone'),
          reason:
              'Sort by Princeps should fallback to label when princepsLabel is null',
        );
        expect(
          sorted[1].label,
          equals('Z-Standalone'),
          reason:
              'Sort by Princeps should fallback to label when princepsLabel is null',
        );
      },
    );

    test(
      'groupByInitial uses princepsLabel when sorting by Princeps',
      () {
        final items = [
          RestockItemEntity(
            cip: Cip13.validated('3400930302613'),
            label: 'Z-Generic',
            princepsLabel: 'A-Princeps',
            quantity: 1,
            isChecked: false,
            isPrinceps: false,
          ),
          RestockItemEntity(
            cip: Cip13.validated('3400930302614'),
            label: 'A-Generic',
            princepsLabel: 'Z-Princeps',
            quantity: 1,
            isChecked: false,
            isPrinceps: false,
          ),
        ];

        final grouped = _groupByInitial(items, SortingPreference.princeps);

        expect(
          grouped.containsKey('A'),
          isTrue,
          reason: 'Group by Princeps should use princepsLabel for grouping',
        );
        expect(
          grouped.containsKey('Z'),
          isTrue,
          reason: 'Group by Princeps should use princepsLabel for grouping',
        );
      },
    );

    test(
      'groupByInitial uses label when sorting by Generic',
      () {
        final items = [
          RestockItemEntity(
            cip: Cip13.validated('3400930302613'),
            label: 'Z-Generic',
            princepsLabel: 'A-Princeps',
            quantity: 1,
            isChecked: false,
            isPrinceps: false,
          ),
          RestockItemEntity(
            cip: Cip13.validated('3400930302614'),
            label: 'A-Generic',
            princepsLabel: 'Z-Princeps',
            quantity: 1,
            isChecked: false,
            isPrinceps: false,
          ),
        ];

        final grouped = _groupByInitial(items, SortingPreference.generic);

        expect(
          grouped.containsKey('A'),
          isTrue,
          reason: 'Group by Generic should use label for grouping',
        );
        expect(
          grouped.containsKey('Z'),
          isTrue,
          reason: 'Group by Generic should use label for grouping',
        );
      },
    );
  });
}
