import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/seed_builder.dart';
import '../../helpers/golden_db_helper.dart';

class _FakeCatalogDao extends Fake implements CatalogDao {
  @override
  Future<List<GenericGroupEntity>> getGenericGroupSummaries({
    List<String>? routeKeywords,
    List<String>? formKeywords,
    List<String>? excludeKeywords,
    List<String>? procedureTypeKeywords,
    String? atcClass,
    int limit = 100,
    int offset = 0,
  }) async {
    final hasFilters = (routeKeywords?.isNotEmpty ?? false) ||
        (formKeywords?.isNotEmpty ?? false) ||
        (excludeKeywords?.isNotEmpty ?? false) ||
        (procedureTypeKeywords?.isNotEmpty ?? false) ||
        (atcClass?.isNotEmpty ?? false);
    if (hasFilters) return const <GenericGroupEntity>[];

    return List.generate(
      5,
      (index) => GenericGroupEntity(
        groupId: GroupId.validated('GRP_FAKE_$index'),
        commonPrincipes: 'AP$index',
        princepsReferenceName: 'Princeps $index',
        princepsCisCode: CisCode.unsafe('CIS_FAKE_$index'),
      ),
    );
  }
}

class _FakeSearchFiltersNotifier extends SearchFiltersNotifier {
  @override
  SearchFilters build() => const SearchFilters();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Explorer Pagination & Filter Logic', () {
    late AppDatabase database;
    late ProviderContainer container;
    Future<void> seedData() async {
      final builder = SeedBuilder();
      for (var i = 0; i < 50; i++) {
        final cip = '340000000${i.toString().padLeft(4, '0')}';
        builder.inGroup('GRP_$i', 'Group $i').addPrinceps(
              'Produit $i',
              cip,
              cipCode: 'CIS_$i',
              form: 'Forme',
              lab: 'LAB_$i',
            );
      }
      await builder.insertInto(database);
      // FTS5 search index should be populated by individual tests if needed

      // Note: The SeedBuilder already creates 50 groups with medications,
      // so there should be data available for pagination testing.
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final preferencesService = PreferencesService(prefs);

      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      await seedData();
      final fakeCatalogDao = _FakeCatalogDao();
      container = ProviderContainer(
        overrides: [
          databaseProvider().overrideWithValue(database),
          catalogDaoProvider.overrideWithValue(fakeCatalogDao),
          searchFiltersProvider.overrideWith(_FakeSearchFiltersNotifier.new),
          preferencesServiceProvider.overrideWithValue(preferencesService),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'initial load returns full dataset without pagination',
      () async {
        final state = await container.read(genericGroupsProvider.future);

        expect(
          state.items,
          hasLength(5),
          reason: 'Full list should be fetched in a single query',
        );
      },
    );

    test(
      'filter application refetches and returns filtered set',
      () async {
        final initialState = await container.read(genericGroupsProvider.future);
        expect(
          initialState.items,
          isNotEmpty,
          reason: 'Baseline should load items before applying filters',
        );

        // Apply a filter that forces an empty result from the fake DAO.
        container.read(searchFiltersProvider.notifier).filters =
            const SearchFilters(voieAdministration: 'Orale');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final afterFilter = await container.read(genericGroupsProvider.future);

        expect(
          afterFilter.items,
          isEmpty,
          reason: 'Filter should refetch and produce filtered results',
        );
      },
    );
  });
}
