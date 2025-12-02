// test/features/explorer/clustering_duplication_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/explorer_grouping_helper.dart';

void main() {
  group('Clustering Duplication Tests - Real World Cases', () {
    test(
      'Mémantine with different dosages should be grouped together',
      () {
        // GIVEN: Mémantine entries with different dosages (10 mg and 20 mg)
        // These should be grouped like Céfépime
        final testItems = [
          const GenericGroupEntity(
            groupId: 'GROUP_MEMANTINE_10',
            commonPrincipes: 'Mémantine (chlorhydrate de)',
            princepsReferenceName: 'AXURA',
            princepsCisCode: '12345678', // Same princeps CIS
          ),
          const GenericGroupEntity(
            groupId: 'GROUP_MEMANTINE_20',
            commonPrincipes: 'Mémantine (chlorhydrate de)',
            princepsReferenceName: 'AXURA',
            princepsCisCode: '12345678', // Same princeps CIS
          ),
        ];

        // WHEN: Group items
        final grouped = ExplorerGroupingHelper.groupByCommonPrincipes(
          testItems,
        );

        // THEN: Should be in a single cluster
        expect(grouped.length, 1, reason: 'Mémantine should be in one cluster');
        expect(
          grouped.first,
          isA<GroupCluster>(),
          reason: 'Mémantine should be a GroupCluster',
        );

        final cluster = grouped.first as GroupCluster;
        expect(
          cluster.groups.length,
          2,
          reason: 'Cluster should contain both Mémantine entries',
        );
        expect(
          cluster.groups.any((g) => g.groupId == 'GROUP_MEMANTINE_10'),
          isTrue,
        );
        expect(
          cluster.groups.any((g) => g.groupId == 'GROUP_MEMANTINE_20'),
          isTrue,
        );
      },
    );

    test(
      'Miansérine with different dosages should be grouped together',
      () {
        // GIVEN: Miansérine entries with different dosages (30 mg and 60 mg)
        final testItems = [
          const GenericGroupEntity(
            groupId: 'GROUP_MIANSERINE_30',
            commonPrincipes: 'Miansérine (chlorhydrate de)',
            princepsReferenceName: 'ATHYMIL',
            princepsCisCode: '87654321', // Same princeps CIS
          ),
          const GenericGroupEntity(
            groupId: 'GROUP_MIANSERINE_60',
            commonPrincipes: 'Miansérine (chlorhydrate de)',
            princepsReferenceName: 'ATHYMIL',
            princepsCisCode: '87654321', // Same princeps CIS
          ),
        ];

        // WHEN: Group items
        final grouped = ExplorerGroupingHelper.groupByCommonPrincipes(
          testItems,
        );

        // THEN: Should be in a single cluster
        expect(
          grouped.length,
          1,
          reason: 'Miansérine should be in one cluster',
        );
        expect(
          grouped.first,
          isA<GroupCluster>(),
          reason: 'Miansérine should be a GroupCluster',
        );

        final cluster = grouped.first as GroupCluster;
        expect(
          cluster.groups.length,
          2,
          reason: 'Cluster should contain both Miansérine entries',
        );
      },
    );

    test(
      'Items with same commonPrincipes but different princepsCisCode should still group if principes match',
      () {
        // GIVEN: Items with same commonPrincipes but potentially different princepsCisCode
        // They should still group by commonPrincipes normalization
        final testItems = [
          const GenericGroupEntity(
            groupId: 'GROUP_A',
            commonPrincipes: 'Mémantine (chlorhydrate de)',
            princepsReferenceName: 'AXURA',
          ),
          const GenericGroupEntity(
            groupId: 'GROUP_B',
            commonPrincipes: 'Mémantine (chlorhydrate de)',
            princepsReferenceName: 'AXURA',
          ),
        ];

        // WHEN: Group items
        final grouped = ExplorerGroupingHelper.groupByCommonPrincipes(
          testItems,
        );

        // THEN: Should be grouped by commonPrincipes normalization
        expect(grouped.length, 1, reason: 'Should group by commonPrincipes');
        expect(
          grouped.first,
          isA<GroupCluster>(),
          reason: 'Should be a GroupCluster',
        );
      },
    );

    test(
      'Real case: Mémantine with different princepsCisCode should still group by commonPrincipes',
      () {
        // GIVEN: Real scenario - Mémantine entries might have different princepsCisCode
        // but same commonPrincipes - they should still group
        final testItems = [
          const GenericGroupEntity(
            groupId: 'GROUP_MEMANTINE_10',
            commonPrincipes: 'Mémantine (chlorhydrate de)',
            princepsReferenceName: 'AXURA 10 mg',
            princepsCisCode: 'CIS_10', // Different CIS codes
          ),
          const GenericGroupEntity(
            groupId: 'GROUP_MEMANTINE_20',
            commonPrincipes: 'Mémantine (chlorhydrate de)',
            princepsReferenceName: 'AXURA 20 mg',
            princepsCisCode: 'CIS_20', // Different CIS codes
          ),
        ];

        // WHEN: Group items
        final grouped = ExplorerGroupingHelper.groupByCommonPrincipes(
          testItems,
        );

        // THEN: Should still group by commonPrincipes (soft link) even with different CIS
        expect(
          grouped.length,
          1,
          reason:
              'Mémantine should group by commonPrincipes even with different CIS codes',
        );
        expect(
          grouped.first,
          isA<GroupCluster>(),
          reason: 'Should be a GroupCluster',
        );
      },
    );

    test(
      'Real case: Miansérine with different princepsCisCode should still group by commonPrincipes',
      () {
        // GIVEN: Real scenario - Miansérine entries with different dosages
        final testItems = [
          const GenericGroupEntity(
            groupId: 'GROUP_MIANSERINE_30',
            commonPrincipes: 'Miansérine (chlorhydrate de)',
            princepsReferenceName: 'ATHYMIL 30 mg',
            princepsCisCode: 'CIS_30',
          ),
          const GenericGroupEntity(
            groupId: 'GROUP_MIANSERINE_60',
            commonPrincipes: 'Miansérine (chlorhydrate de)',
            princepsReferenceName: 'ATHYMIL 60 mg',
            princepsCisCode: 'CIS_60',
          ),
        ];

        // WHEN: Group items
        final grouped = ExplorerGroupingHelper.groupByCommonPrincipes(
          testItems,
        );

        // THEN: Should group by commonPrincipes
        expect(
          grouped.length,
          1,
          reason: 'Miansérine should group by commonPrincipes',
        );
        expect(
          grouped.first,
          isA<GroupCluster>(),
          reason: 'Should be a GroupCluster',
        );
      },
    );
  });
}
