// ignore_for_file: undefined_function, undefined_identifier
// Test file uses generated companion types from Drift

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';

import '../../fixtures/seed_builder.dart';

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
    final hasFilters =
        (routeKeywords?.isNotEmpty ?? false) ||
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
        builder
            .inGroup('GRP_$i', 'Group $i')
            .addPrinceps(
              'Produit $i',
              cip,
              cipCode: 'CIS_$i',
              form: 'Forme',
              lab: 'LAB_$i',
            );
      }
      await builder.insertInto(database);
      await database.databaseDao.populateFts5Index();

      // Ensure at least one group summary exists for pagination assertions.
      final summaries = await database.viewGenericGroupSummaries.all().get();
      if (summaries.isEmpty) {
        await database
            .into(database.generiqueGroups)
            .insert(
              GeneriqueGroupsCompanion(
                groupId: const drift.Value('GRP_FALLBACK'),
                libelle: const drift.Value('Fallback Group'),
                rawLabel: const drift.Value('Fallback Group'),
                parsingMethod: const drift.Value('manual'),
              ),
            );
        await database
            .into(database.groupMembers)
            .insert(
              GroupMembersCompanion(
                groupId: const drift.Value('GRP_FALLBACK'),
                codeCip: const drift.Value('3400000099999'),
                type: const drift.Value(0),
              ),
            );
        await database
            .into(database.medicamentSummary)
            .insert(
              MedicamentSummaryCompanion.insert(
                cisCode: 'CIS_FALLBACK',
                nomCanonique: 'Fallback Drug',
                isPrinceps: true,
                groupId: const drift.Value('GRP_FALLBACK'),
                memberType: const drift.Value(0),
                principesActifsCommuns: <String>['ACTIVE_PRINCIPLE'],
                princepsDeReference: 'Fallback Drug',
                princepsBrandName: 'Fallback Drug',
                procedureType: const drift.Value('AMM'),
                conditionsPrescription: const drift.Value(null),
                dateAmm: const drift.Value(null),
                isSurveillance: const drift.Value(false),
                formattedDosage: const drift.Value('500 mg'),
                atcCode: const drift.Value('A00'),
                status: const drift.Value('active'),
                priceMin: const drift.Value(null),
                priceMax: const drift.Value(null),
                voiesAdministration: const drift.Value('orale'),
                formePharmaceutique: const drift.Value('Forme'),
              ),
            );
      }
    }

    setUp(() async {
      database = AppDatabase.forTesting(
        NativeDatabase.memory(setup: configureAppSQLite),
      );

      await seedData();
      final fakeCatalogDao = _FakeCatalogDao();
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          catalogDaoProvider.overrideWithValue(fakeCatalogDao),
          searchFiltersProvider.overrideWith(_FakeSearchFiltersNotifier.new),
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
