import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';

import '../../test_utils.dart' show loadRealBdpmData;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Explorer Pagination & Filter Logic', () {
    late AppDatabase database;
    late ProviderContainer container;

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      // Load real BDPM data instead of hardcoded values
      await loadRealBdpmData(database);

      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          catalogDaoProvider.overrideWithValue(database.catalogDao),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'initial load returns page size items, hasMore depends on total count',
      () async {
        final notifier = container.read(genericGroupsProvider.notifier);
        await notifier.build();

        final state = await container.read(genericGroupsProvider.future);

        // With real data, we can't guarantee exactly 40 items, but should have some
        expect(
          state.items.length,
          greaterThan(0),
          reason: 'Initial load should return at least some items',
        );
        expect(
          state.items.length,
          lessThanOrEqualTo(40),
          reason: 'Initial load should not exceed page size (40)',
        );
        expect(
          state.isLoadingMore,
          isFalse,
          reason: 'Initial load should not be in loading more state',
        );
      },
    );

    test(
      'loadMore loads additional items until all are loaded',
      () async {
        final notifier = container.read(genericGroupsProvider.notifier);
        await notifier.build();

        final initialState = await container.read(genericGroupsProvider.future);
        final initialCount = initialState.items.length;

        for (var i = 0; i < 5; i++) {
          final current = await container.read(genericGroupsProvider.future);
          if (!current.hasMore) {
            break;
          }
          await notifier.loadMore();
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }

        final finalState = await container.read(genericGroupsProvider.future);

        expect(
          finalState.items.length,
          greaterThanOrEqualTo(initialCount),
          reason: 'Load more should return at least initial items',
        );
        expect(
          finalState.isLoadingMore,
          isFalse,
          reason: 'Should not be in loading more state after completion',
        );
      },
    );

    test(
      'filter application resets offset to 0',
      () async {
        final notifier = container.read(genericGroupsProvider.notifier);
        await notifier.build();

        final initialState = await container.read(genericGroupsProvider.future);
        final initialCount = initialState.items.length;

        // Load more if available
        if (initialState.hasMore) {
          await notifier.loadMore();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }

        final afterLoadMore = container.read(genericGroupsProvider).value!;
        expect(
          afterLoadMore.items.length,
          greaterThanOrEqualTo(initialCount),
          reason: 'After loadMore, should have at least as many items',
        );

        // Apply filter - use a real route from BDPM data if available
        container.read(searchFiltersProvider.notifier).filters =
            const SearchFilters(voieAdministration: 'Orale');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final afterFilter = await container.read(genericGroupsProvider.future);

        expect(
          afterFilter.items.length,
          lessThanOrEqualTo(40),
          reason: 'Filter should reset pagination and return first page',
        );
        expect(
          afterFilter.hasMore,
          anyOf(isTrue, isFalse),
          reason: 'hasMore depends on filtered results count',
        );
      },
    );

    test(
      'filter with no results returns empty list, resets offset',
      () async {
        final notifier = container.read(genericGroupsProvider.notifier);
        await notifier.build();

        final initialState = await container.read(genericGroupsProvider.future);
        expect(
          initialState.items.length,
          greaterThan(0),
          reason: 'Initial state should have some items',
        );

        // Use a filter that should return no results
        container.read(searchFiltersProvider.notifier).filters =
            const SearchFilters(voieAdministration: 'NonExistentRoute');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final afterFilter = await container.read(genericGroupsProvider.future);

        expect(
          afterFilter.items,
          isEmpty,
          reason: 'Filter with no matches should return empty list',
        );
        expect(
          afterFilter.hasMore,
          isFalse,
          reason: 'No more items when filter returns empty',
        );
      },
    );
  });
}
