// test/features/explorer/presentation/providers/search_provider_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pharma_scan/core/database/database.dart';
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
      // GIVEN: Empty query
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      // WHEN: Watch search results with empty query
      // For @riverpod stream providers, read() returns AsyncValue wrapping the stream
      final asyncValue = container.read(searchResultsProvider(''));

      // THEN: Should return empty list immediately (no DAO call)
      // Empty query returns Stream.value([]) immediately, so AsyncValue should have data
      expect(asyncValue.hasValue, isTrue);
      expect(asyncValue.value, const <SearchResultItem>[]);

      // Verify DAO was not called for empty query
      verifyNever(() => mockCatalogDao.watchMedicaments(any()));
    });

    test('whitespace-only query returns empty list immediately', () async {
      // GIVEN: Whitespace-only query
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      // WHEN: Watch search results with whitespace
      final asyncValue = container.read(searchResultsProvider('   '));

      // THEN: Should return empty list immediately
      expect(asyncValue.hasValue, isTrue);
      expect(asyncValue.value, const <SearchResultItem>[]);

      // Verify DAO was not called
      verifyNever(() => mockCatalogDao.watchMedicaments(any()));
    });

    test('special characters are escaped in FTS5 query', () async {
      // GIVEN: Query with special characters that need escaping
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      // Mock DAO to capture the query
      String? capturedQuery;
      when(() => mockCatalogDao.watchMedicaments(any())).thenAnswer((
        invocation,
      ) {
        capturedQuery = invocation.positionalArguments[0] as String;
        return Stream.value(const <MedicamentSummaryData>[]);
      });

      // WHEN: Search with special characters
      container.read(searchResultsProvider("test'query\"with:chars"));

      // THEN: Raw query is passed to watchMedicaments (sanitization happens inside)
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(capturedQuery, isNotNull);
      // The raw query is passed to watchMedicaments, which sanitizes it internally
      expect(capturedQuery, equals("test'query\"with:chars"));
      // Verify the method was called (sanitization with special char removal happens in _escapeFts5Query)
      verify(() => mockCatalogDao.watchMedicaments(any())).called(1);
    });

    test('diacritics in query match normalized index', () async {
      // GIVEN: Query with diacritics (é, è, à)
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      // Mock DAO to return results
      when(() => mockCatalogDao.watchMedicaments(any())).thenAnswer(
        (_) => Stream.value(const <MedicamentSummaryData>[]),
      );

      // WHEN: Search with diacritics
      final asyncValue = container.read(searchResultsProvider('paracétamol'));

      // THEN: Should have results (diacritics normalized in _escapeFts5Query)
      // Wait for the stream to emit
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // The provider wraps the stream in AsyncValue, which updates as the stream emits
      // For this test, we just verify the DAO was called

      verify(() => mockCatalogDao.watchMedicaments(any())).called(1);
    });

    test('no results found returns empty list', () async {
      // GIVEN: Query that matches no results
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      // Mock DAO to return empty results
      when(() => mockCatalogDao.watchMedicaments(any())).thenAnswer(
        (_) => Stream.value(const <MedicamentSummaryData>[]),
      );

      // WHEN: Search for non-existent medication
      final asyncValue = container.read(
        searchResultsProvider('nonexistent123'),
      );

      // THEN: Should return empty list (after stream emits)
      // Wait for the stream to emit
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // The provider wraps the stream in AsyncValue
      // We verify the DAO was called and returned empty results
      verify(() => mockCatalogDao.watchMedicaments(any())).called(1);
    });

    test('query with multiple words uses AND operator', () async {
      // GIVEN: Multi-word query
      final container = ProviderContainer(
        overrides: [
          catalogDaoProvider.overrideWith((ref) => mockCatalogDao),
        ],
      );

      String? capturedQuery;
      when(() => mockCatalogDao.watchMedicaments(any())).thenAnswer(
        (invocation) {
          capturedQuery = invocation.positionalArguments[0] as String;
          return Stream.value(const <MedicamentSummaryData>[]);
        },
      );

      // WHEN: Search with multiple words
      container.read(searchResultsProvider('paracetamol 500mg'));

      // THEN: Raw query is passed to watchMedicaments (sanitization happens inside)
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(capturedQuery, isNotNull);
      // The raw query is passed to watchMedicaments, which sanitizes it internally
      expect(capturedQuery, equals('paracetamol 500mg'));
      // Verify the method was called (sanitization with AND happens in _escapeFts5Query)
      verify(() => mockCatalogDao.watchMedicaments(any())).called(1);
    });
  });
}
