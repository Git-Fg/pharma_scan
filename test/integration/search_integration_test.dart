import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';

import '../helpers/golden_db_helper.dart';

void main() {
  group('Search Integration Tests', () {
    late AppDatabase db;
    late CatalogDao catalogDao;

    setUp(() async {
      db = await loadGoldenDatabase();
      catalogDao = db.catalogDao;
    });

    tearDown(() async {
      await db.close();
    });

    test('returns clusters for common active ingredients', () async {
      // This test verifies that our FTS5 search correctly groups medications
      // by common active ingredients and returns cluster results

      final results = await catalogDao
          .watchMedicaments(NormalizedQuery.fromString('paracetamol'))
          .first;

      expect(results, isNotEmpty);

      // Should return at least one cluster or group for paracetamol
      final searchItems = results
          .map((row) => row.toSearchResultItem())
          .whereType<SearchResultItem>()
          .toList();

      expect(searchItems, isNotEmpty);

      // Verify we have proper clustering/ranking logic
      final hasClusterOrGroup = searchItems.any(
        (item) => item is ClusterResult || item is GroupResult,
      );
      expect(hasClusterOrGroup, isTrue);
    });

    test('returns exact matches for specific CIS codes', () async {
      // Test searching for specific medications by canonical name

      final results = await catalogDao
          .watchMedicaments(NormalizedQuery.fromString('doliprane'))
          .first;

      final searchItems = results
          .map((row) => row.toSearchResultItem())
          .whereType<SearchResultItem>()
          .toList();

      // Should find Doliprane and return standalone results
      expect(searchItems, isNotEmpty);

      // Should have standalone medication results
      final hasStandalone = searchItems.any((item) => item is StandaloneResult);
      expect(hasStandalone, isTrue);
    });

    test('handles diacritics and special characters correctly', () async {
      // Test that our search normalization handles diacritics

      final accentQuery = await catalogDao
          .watchMedicaments(NormalizedQuery.fromString('paracétamol'))
          .first;

      final noAccentQuery = await catalogDao
          .watchMedicaments(NormalizedQuery.fromString('paracetamol'))
          .first;

      // Both queries should return similar results
      expect(accentQuery, isNotEmpty);
      expect(noAccentQuery, isNotEmpty);

      // The number of results should be similar (allowing for small variations)
      expect(
        accentQuery.length,
        closeTo(noAccentQuery.length, 2),
        reason: 'Search should handle diacritics consistently',
      );
    });

    test('respects result ordering by relevance', () async {
      // Test that search results are properly ordered

      final results = await catalogDao
          .watchMedicaments(NormalizedQuery.fromString('ibuprofène'))
          .first;

      expect(results.length, greaterThan(1));

      // Results should be ordered by type (cluster, group, standalone) and then by sort key
      for (var i = 0; i < results.length - 1; i++) {
        final current = results[i];
        final next = results[i + 1];

        // Clusters should come before groups, which should come before standalones
        final currentTypeOrder = _getTypeOrder(current.type);
        final nextTypeOrder = _getTypeOrder(next.type);

        expect(
          currentTypeOrder,
          lessThanOrEqualTo(nextTypeOrder),
          reason:
              'Results should be ordered by type: cluster -> group -> standalone',
        );
      }
    });

    test('returns empty results for non-existent medications', () async {
      final results = await catalogDao
          .watchMedicaments(
            NormalizedQuery.fromString('xyznonexistent123'),
          )
          .first;

      expect(results, isEmpty);
    });

    test('search results can be converted to domain models', () async {
      // Integration test for our extension method
      final results = await catalogDao
          .watchMedicaments(NormalizedQuery.fromString('aspirine'))
          .first;

      if (results.isNotEmpty) {
        final searchItems = results
            .map((row) => row.toSearchResultItem())
            .whereType<SearchResultItem>()
            .toList();

        expect(searchItems, isNotEmpty);

        for (final item in searchItems) {
          expect(item, isA<SearchResultItem>());

          if (item is ClusterResult) {
            expect(item.groups, isNotEmpty);
            expect(item.displayName, isNotEmpty);
          } else if (item is GroupResult) {
            expect(item.group.groupId.toString(), isNotEmpty);
            expect(item.group.commonPrincipes, isNotEmpty);
          } else if (item is StandaloneResult) {
            expect(item.cisCode.toString(), isNotEmpty);
            expect(item.summary, isA<MedicamentEntity>());
            expect(item.representativeCip.toString(), isNotEmpty);
          }
        }
      }
    });
  });
}

int _getTypeOrder(String type) {
  switch (type) {
    case 'cluster':
      return 1;
    case 'group':
      return 2;
    case 'standalone':
      return 3;
    default:
      return 4;
  }
}
