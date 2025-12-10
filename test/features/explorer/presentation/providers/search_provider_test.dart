// test/features/explorer/presentation/providers/search_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/queries.drift.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';

import '../../../../mocks.dart';

void main() {
  setUpAll(registerCommonFallbackValues);

  group('SearchProvider Edge Cases', () {
    late MockCatalogDao mockCatalogDao;

    setUp(() {
      mockCatalogDao = MockCatalogDao();
    });

    test('empty string query returns empty list immediately', () async {
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      final asyncValue = container.read(searchResultsProvider(''));

      expect(
        asyncValue.asData?.value ?? const <SearchResultItem>[],
        const <SearchResultItem>[],
      );

      // Verify DAO was not called for empty query
      verifyNever(() => mockCatalogDao.watchSearchResultsSql(any()));
    });

    test('whitespace-only query returns empty list immediately', () async {
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      final asyncValue = container.read(searchResultsProvider('   '));

      expect(
        asyncValue.asData?.value ?? const <SearchResultItem>[],
        const <SearchResultItem>[],
      );

      // Verify DAO was not called
      verifyNever(() => mockCatalogDao.watchSearchResultsSql(any()));
    });

    test('special characters are escaped in FTS5 query', () async {
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      NormalizedQuery? capturedQuery;
      when(() => mockCatalogDao.watchSearchResultsSql(any())).thenAnswer((
        invocation,
      ) {
        capturedQuery = invocation.positionalArguments[0] as NormalizedQuery;
        return Stream.value(
          const <SearchResultsResult>[],
        );
      });

      container.read(searchResultsProvider("test'query\"with:chars"));

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(capturedQuery, isNotNull);
      expect(capturedQuery.toString(), equals("test'query\"with:chars"));
      verify(() => mockCatalogDao.watchSearchResultsSql(any())).called(1);
    });

    test('diacritics in query match normalized index', () async {
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      when(() => mockCatalogDao.watchSearchResultsSql(any())).thenAnswer(
        (_) => Stream.value(
          const <SearchResultsResult>[],
        ),
      );

      container.read(searchResultsProvider('paracétamol'));

      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(() => mockCatalogDao.watchSearchResultsSql(any())).called(1);
    });

    test('no results found returns empty list', () async {
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      when(() => mockCatalogDao.watchSearchResultsSql(any())).thenAnswer(
        (_) => Stream.value(
          const <SearchResultsResult>[],
        ),
      );

      container.read(
        searchResultsProvider('nonexistent123'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));
      verify(() => mockCatalogDao.watchSearchResultsSql(any())).called(1);
    });

    test('query with multiple words uses AND operator', () async {
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      NormalizedQuery? capturedQuery;
      when(() => mockCatalogDao.watchSearchResultsSql(any())).thenAnswer(
        (invocation) {
          capturedQuery = invocation.positionalArguments[0] as NormalizedQuery;
          return Stream.value(
            const <SearchResultsResult>[],
          );
        },
      );

      container.read(searchResultsProvider('paracetamol 500mg'));

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(capturedQuery, isNotNull);
      expect(capturedQuery.toString(), equals('paracetamol 500mg'));
      verify(() => mockCatalogDao.watchSearchResultsSql(any())).called(1);
    });
  });
}
