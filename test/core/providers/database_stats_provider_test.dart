@Tags(['providers'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/domain/models/database_stats.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/database_stats_provider.dart';
import 'package:riverpod/riverpod.dart';

class MockCatalogDao extends Mock implements CatalogDao {}

void main() {
  group('DatabaseStatsProvider', () {
    late MockCatalogDao mockCatalogDao;

    setUp(() {
      mockCatalogDao = MockCatalogDao();
    });

    test('returns DatabaseStats from catalogDao', () async {
      final expectedStats = (
        totalPrinceps: 5000,
        totalGeneriques: 10000,
        totalPrincipes: 800,
        avgGenPerPrincipe: 12.5,
      );

      when(() => mockCatalogDao.getDatabaseStats())
          .thenAnswer((_) async => expectedStats);

      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((_) => mockCatalogDao),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(databaseStatsProvider.future);

      expect(result, expectedStats);
      verify(() => mockCatalogDao.getDatabaseStats()).called(1);
    });

    test('handles error from catalogDao', () async {
      when(() => mockCatalogDao.getDatabaseStats())
          .thenAnswer((_) async => throw Exception('Database error'));

      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((_) => mockCatalogDao),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(databaseStatsProvider);
      expect(result, isA<AsyncValue<DatabaseStats>>());

      await Future<void>.delayed(Duration.zero);
      expect(
        result.when(
          data: (_) => false,
          loading: () => true,
          error: (_, __) => true,
        ),
        true,
      );
      verify(() => mockCatalogDao.getDatabaseStats()).called(1);
    });

    test('databaseStats returns AsyncValue', () {
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((_) => mockCatalogDao),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(databaseStatsProvider);
      expect(result, isA<AsyncValue<DatabaseStats>>());
    });
  });
}
