// test/features/explorer/clustering_memantine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/explorer_grouping_helper.dart';

void main() {
  group('Mémantine Clustering', () {
    test('should cluster Mémantine groups with same commonPrinciples', () {
      // Simuler les groupes de Mémantine avec les commonPrinciples normalisés
      const group1119 = GenericGroupEntity(
        groupId: '1119',
        commonPrincipes: 'MEMANTINE',
        princepsReferenceName: 'AXURA 10 mg, comprimé pelliculé',
      );

      const group1120 = GenericGroupEntity(
        groupId: '1120',
        commonPrincipes: 'MEMANTINE',
        princepsReferenceName: 'AXURA 20 mg, comprimé pelliculé',
      );

      const group1187 = GenericGroupEntity(
        groupId: '1187',
        commonPrincipes: 'MEMANTINE',
        princepsReferenceName: 'EBIXA 5 mg/pression, solution buvable',
      );

      final items = [group1119, group1120, group1187];

      // Appliquer la logique de clustering
      final result = ExplorerGroupingHelper.groupByCommonPrincipes(items);

      // Vérifier que tous les groupes sont dans un seul cluster
      expect(
        result.length,
        equals(1),
        reason: 'All Mémantine groups should be in a single cluster',
      );

      expect(
        result.first,
        isA<GroupCluster>(),
        reason: 'Result should be a GroupCluster',
      );

      final cluster = result.first as GroupCluster;
      expect(
        cluster.groups.length,
        equals(3),
        reason: 'Cluster should contain all 3 Mémantine groups',
      );

      // Vérifier que le displayName contient "MEMANTINE"
      expect(
        cluster.displayName.toUpperCase(),
        contains('MEMANTINE'),
        reason: 'Cluster display name should contain MEMANTINE',
      );
    });

    test('normalizeCommonPrincipes should handle "MEMANTINE" correctly', () {
      final result = ExplorerGroupingHelper.normalizeCommonPrincipes(
        'MEMANTINE',
      );
      expect(
        result,
        equals('MEMANTINE'),
        reason: 'Already normalized "MEMANTINE" should remain "MEMANTINE"',
      );
    });

    test(
      'normalizePrincipleOptimal should handle "MÉMANTINE (CHLORHYDRATE DE)" correctly',
      () {
        final result = normalizePrincipleOptimal('MÉMANTINE (CHLORHYDRATE DE)');
        expect(
          result,
          equals('MEMANTINE'),
          reason: "Should extract MEMANTINE (group 1) since it's not a mineral",
        );
      },
    );
  });
}
