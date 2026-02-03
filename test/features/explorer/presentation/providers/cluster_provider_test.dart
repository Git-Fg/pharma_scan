import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:path/path.dart' as p;

// Test data - Real Cluster IDs from reference.db
const clusterTagamet = 'SCL_00587'; // TAGAMET 200 MG
const clusterRaniplex = 'SCL_49632'; // RANIPLEX

AppDatabase createTestDatabase({
  void Function(dynamic)? setup,
  bool useRealReferenceDatabase = false,
}) {
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      logStatements: true,
      setup: (db) {
        if (useRealReferenceDatabase) {
          final referenceDbPath = p.join(
            p.current,
            'assets',
            'test',
            'reference.db',
          );
          final referenceFile = File(referenceDbPath);

          if (!referenceFile.existsSync()) {
            throw Exception(
              'Reference DB not found at $referenceDbPath',
            );
          }

          final tempDir = Directory.systemTemp.createTempSync('pharma_scan_test_ref_');
          final tempDbFile = File(p.join(tempDir.path, 'reference_copy.db'));
          referenceFile.copySync(tempDbFile.path);

          final absolutePath = tempDbFile.absolute.path;
          db.execute("ATTACH DATABASE '$absolutePath' AS reference_db");
        }

        setup?.call(db);
      },
    ),
    LoggerService(),
  );
}

void main() {
  late AppDatabase database;

  setUp(() async {
    database = createTestDatabase(useRealReferenceDatabase: true);
  });

  tearDown(() async {
    await database.close();
  });

  group('clusterSearchProvider - Real Database Tests', () {
    test('empty query returns all clusters ordered by princeps', () async {
      final clusters = await database.explorerDao.watchClusters('').first;

      expect(clusters, isNotEmpty);
      expect(clusters.length, greaterThan(0));

      final firstCluster = clusters.first;
      expect(firstCluster.id, isNotNull);
      expect(firstCluster.title, isNotEmpty);
    });

    test('non-empty query returns matching clusters', () async {
      final clusters = await database.explorerDao.watchClusters('TAGAMET').first;

      expect(clusters, isNotEmpty);

      final tagametCluster = clusters.firstWhere(
        (c) => c.id == clusterTagamet,
        orElse: () => throw Exception('TAGAMET cluster not found'),
      );

      expect(tagametCluster.id, clusterTagamet);
      expect(tagametCluster.title.toLowerCase(), contains('tagamet'));
    });

    test('search query is case-insensitive', () async {
      final lowerResults = await database.explorerDao.watchClusters('tagamet').first;
      final upperResults = await database.explorerDao.watchClusters('TAGAMET').first;

      expect(lowerResults.length, upperResults.length);
      expect(lowerResults.first.id, upperResults.first.id);
    });

    test('search query with partial match returns results', () async {
      final clusters = await database.explorerDao.watchClusters('RANI').first;

      expect(clusters, isNotEmpty);

      final raniplexCluster = clusters.firstWhere(
        (c) => c.id == clusterRaniplex,
        orElse: () => throw Exception('RANIPLEX cluster not found'),
      );

      expect(raniplexCluster.id, clusterRaniplex);
    });

    test('search with no results returns empty list', () async {
      final clusters = await database.explorerDao
          .watchClusters('XYZNONEXISTENTMEDICINE123')
          .first;

      expect(clusters, isEmpty);
    });

    test('clusters from empty query have required properties', () async {
      final clusters = await database.explorerDao.watchClusters('').first;
      final firstCluster = clusters.first;

      expect(firstCluster.id, isNotNull);
      expect(firstCluster.title, isNotEmpty);
      expect(firstCluster.subtitle, isA<String>());
      expect(firstCluster.productCount, greaterThanOrEqualTo(0));
      expect(firstCluster.displayText, contains(firstCluster.title));
    });

    test('clusters from search have subtitle info', () async {
      final clusters = await database.explorerDao.watchClusters('TAGAMET').first;
      final tagametCluster = clusters.firstWhere(
        (c) => c.id == clusterTagamet,
        orElse: () => throw Exception('TAGAMET cluster not found'),
      );

      expect(tagametCluster.subtitle, isNotEmpty);
      expect(tagametCluster.subtitle.toLowerCase(), contains('tagamet'));
    });
  });

  group('clusterContentProvider - Real Database Tests', () {
    test('returns products for a valid cluster', () async {
      final products = await database.explorerDao.getClusterContent(clusterTagamet);

      expect(products, isNotEmpty);
      expect(products.first.cisCode, isNotNull);
      expect(products.first.name, isNotEmpty);
    });

    test('products are ordered with princeps first', () async {
      final products = await database.explorerDao.getClusterContent(clusterTagamet);

      expect(products, isNotEmpty);

      final firstProduct = products.first;
      expect(firstProduct.isPrinceps, isTrue);
    });

    test('products have required properties', () async {
      final products = await database.explorerDao.getClusterContent(clusterTagamet);
      final firstProduct = products.first;

      expect(firstProduct.cisCode, isNotNull);
      expect(firstProduct.name, isNotEmpty);
      expect(firstProduct.clusterId, clusterTagamet);
      expect(firstProduct.isPrinceps, isA<bool>());
    });

    test('returns empty list for non-existent cluster', () async {
      final products =
          await database.explorerDao.getClusterContent('NONEXISTENT_CLUSTER_ID');

      expect(products, isEmpty);
    });

    test('different clusters return different products', () async {
      final tagametProducts =
          await database.explorerDao.getClusterContent(clusterTagamet);
      final raniplexProducts =
          await database.explorerDao.getClusterContent(clusterRaniplex);

      expect(tagametProducts, isNotEmpty);
      expect(raniplexProducts, isNotEmpty);

      final tagametCisCodes = {
        for (final p in tagametProducts) p.cisCode,
      };
      final raniplexCisCodes = {
        for (final p in raniplexProducts) p.cisCode,
      };

      expect(tagametCisCodes.intersection(raniplexCisCodes), isEmpty);
    });
  });

  group('ClusterEntity - Extension Type Tests', () {
    test('ClusterEntity provides correct id', () async {
      final clusters = await database.explorerDao.watchClusters('TAGAMET').first;
      final cluster = clusters.firstWhere(
        (c) => c.id == clusterTagamet,
        orElse: () => throw Exception('TAGAMET cluster not found'),
      );

      expect(cluster.id, clusterTagamet);
      expect(cluster.id, isA<String>());
    });

    test('ClusterEntity displayText includes product count', () async {
      final clusters = await database.explorerDao.watchClusters('TAGAMET').first;
      final cluster = clusters.firstWhere(
        (c) => c.id == clusterTagamet,
        orElse: () => throw Exception('TAGAMET cluster not found'),
      );

      if (cluster.productCount > 0) {
        expect(cluster.displayText, contains(cluster.title));
        expect(cluster.displayText, contains('(${cluster.productCount})'));
      } else {
        expect(cluster.displayText, cluster.title);
      }
    });

    test('ClusterProductEntity isPrinceps correctly interprets database value', () async {
      final products = await database.explorerDao.getClusterContent(clusterTagamet);

      final princepsProducts = products.where((p) => p.isPrinceps).toList();

      expect(princepsProducts, isNotEmpty);

      for (final product in princepsProducts) {
        expect(product.dbData.isPrinceps, 1);
      }
    });
  });
}
