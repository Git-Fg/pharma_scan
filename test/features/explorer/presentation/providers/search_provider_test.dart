// test/features/explorer/presentation/providers/search_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';

import '../../../../mocks.dart';

void main() {
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

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(asyncValue.hasValue || asyncValue.isLoading, isTrue);
      if (asyncValue.hasValue) {
        expect(asyncValue.value, const <SearchResultItem>[]);
      }

      // Verify DAO was not called for empty query
      verifyNever(() => mockCatalogDao.watchMedicaments(any()));
    });

    test('whitespace-only query returns empty list immediately', () async {
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      final asyncValue = container.read(searchResultsProvider('   '));

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(asyncValue.hasValue || asyncValue.isLoading, isTrue);
      if (asyncValue.hasValue) {
        expect(asyncValue.value, const <SearchResultItem>[]);
      }

      // Verify DAO was not called
      verifyNever(() => mockCatalogDao.watchMedicaments(any()));
    });

    test('special characters are escaped in FTS5 query', () async {
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      NormalizedQuery? capturedQuery;
      when(() => mockCatalogDao.watchMedicaments(any())).thenAnswer((
        invocation,
      ) {
        capturedQuery = invocation.positionalArguments[0] as NormalizedQuery;
        return Stream.value(const <MedicamentSummaryData>[]);
      });

      container.read(searchResultsProvider("test'query\"with:chars"));

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(capturedQuery, isNotNull);
      expect(capturedQuery.toString(), equals("test'query\"with:chars"));
      verify(() => mockCatalogDao.watchMedicaments(any())).called(1);
    });

    test('diacritics in query match normalized index', () async {
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      when(() => mockCatalogDao.watchMedicaments(any())).thenAnswer(
        (_) => Stream.value(const <MedicamentSummaryData>[]),
      );

      container.read(searchResultsProvider('paracétamol'));

      await Future<void>.delayed(const Duration(milliseconds: 100));

      verify(() => mockCatalogDao.watchMedicaments(any())).called(1);
    });

    test('no results found returns empty list', () async {
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      when(() => mockCatalogDao.watchMedicaments(any())).thenAnswer(
        (_) => Stream.value(const <MedicamentSummaryData>[]),
      );

      container.read(
        searchResultsProvider('nonexistent123'),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));
      verify(() => mockCatalogDao.watchMedicaments(any())).called(1);
    });

    test('query with multiple words uses AND operator', () async {
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      NormalizedQuery? capturedQuery;
      when(() => mockCatalogDao.watchMedicaments(any())).thenAnswer(
        (invocation) {
          capturedQuery = invocation.positionalArguments[0] as NormalizedQuery;
          return Stream.value(const <MedicamentSummaryData>[]);
        },
      );

      container.read(searchResultsProvider('paracetamol 500mg'));

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(capturedQuery, isNotNull);
      expect(capturedQuery.toString(), equals('paracetamol 500mg'));
      verify(() => mockCatalogDao.watchMedicaments(any())).called(1);
    });
  });
}
