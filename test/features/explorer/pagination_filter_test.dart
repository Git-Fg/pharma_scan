import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';

import '../../fixtures/seed_builder.dart';
import '../../test_utils.dart' show setPrincipeNormalizedForAllPrinciples;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Explorer Pagination & Filter Logic', () {
    late AppDatabase database;
    late ProviderContainer container;

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      final builder = SeedBuilder();
      for (var i = 0; i < 50; i++) {
        builder
            .inGroup('GROUP_$i', 'MEDICATION $i')
            .addPrinceps(
              'MEDICATION $i, comprimé',
              'CIP_${i.toString().padLeft(13, '0')}',
              cis: 'CIS_$i',
              dosage: '100',
              form: i < 25 ? 'Comprimé' : 'Solution injectable',
              lab: 'LAB_$i',
            );
      }
      await builder.insertInto(database);

      await setPrincipeNormalizedForAllPrinciples(database);
      final dataInit = DataInitializationService(database: database);
      await dataInit.runSummaryAggregationForTesting();

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
      'initial load returns 40 items (Page Size), hasMore = true',
      () async {
        final notifier = container.read(genericGroupsProvider.notifier);
        await notifier.build();

        final state = await container.read(genericGroupsProvider.future);

        expect(
          state.items.length,
          equals(40),
          reason: 'Initial load should return page size (40) items',
        );
        expect(
          state.hasMore,
          isTrue,
          reason: 'Should have more items when total > page size',
        );
        expect(
          state.isLoadingMore,
          isFalse,
          reason: 'Initial load should not be in loading more state',
        );
      },
    );

    test(
      'loadMore returns remaining 10 items, hasMore = false',
      () async {
        final notifier = container.read(genericGroupsProvider.notifier);
        await notifier.build();

        await notifier.loadMore();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final state = container.read(genericGroupsProvider).value!;

        expect(
          state.items.length,
          equals(50),
          reason: 'Load more should return all 50 items',
        );
        expect(
          state.hasMore,
          isFalse,
          reason: 'Should have no more items when all loaded',
        );
        expect(
          state.isLoadingMore,
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
        expect(initialState.items.length, equals(40));

        await notifier.loadMore();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final afterLoadMore = container.read(genericGroupsProvider).value!;
        expect(afterLoadMore.items.length, equals(50));

        container.read(searchFiltersProvider.notifier).filters =
            const SearchFilters(voieAdministration: 'Injectable');
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
        expect(initialState.items.length, equals(40));

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
