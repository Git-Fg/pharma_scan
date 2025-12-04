// test/features/explorer/clustering_duplication_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/features/explorer/domain/logic/explorer_grouping_helper.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';

void main() {
  group('Clustering Duplication Tests - Real World Cases', () {
    test(
      'Mémantine with different dosages should be grouped together',
      () {
        final testItems = [
          GenericGroupEntity(
            groupId: GroupId('GROUP_MEMANTINE_10'),
            commonPrincipes: 'Mémantine (chlorhydrate de)',
            princepsReferenceName: 'AXURA',
            princepsCisCode: CisCode('12345678'), // Same princeps CIS
          ),
          GenericGroupEntity(
            groupId: GroupId('GROUP_MEMANTINE_20'),
            commonPrincipes: 'Mémantine (chlorhydrate de)',
            princepsReferenceName: 'AXURA',
            princepsCisCode: CisCode('12345678'), // Same princeps CIS
          ),
        ];

        final grouped = ExplorerGroupingHelper.groupByCommonPrincipes(
          testItems,
        );

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
          cluster.groups.any(
            (g) => g.groupId.toString() == 'GROUP_MEMANTINE_10',
          ),
          isTrue,
        );
        expect(
          cluster.groups.any(
            (g) => g.groupId.toString() == 'GROUP_MEMANTINE_20',
          ),
          isTrue,
        );
      },
    );

    test(
      'Miansérine with different dosages should be grouped together',
      () {
        final testItems = [
          GenericGroupEntity(
            groupId: GroupId('GROUP_MIANSERINE_30'),
            commonPrincipes: 'Miansérine (chlorhydrate de)',
            princepsReferenceName: 'ATHYMIL',
            princepsCisCode: CisCode('87654321'), // Same princeps CIS
          ),
          GenericGroupEntity(
            groupId: GroupId('GROUP_MIANSERINE_60'),
            commonPrincipes: 'Miansérine (chlorhydrate de)',
            princepsReferenceName: 'ATHYMIL',
            princepsCisCode: CisCode('87654321'), // Same princeps CIS
          ),
        ];

        final grouped = ExplorerGroupingHelper.groupByCommonPrincipes(
          testItems,
        );

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
        final testItems = [
          GenericGroupEntity(
            groupId: GroupId('GROUP_A'),
            commonPrincipes: 'Mémantine (chlorhydrate de)',
            princepsReferenceName: 'AXURA',
          ),
          GenericGroupEntity(
            groupId: GroupId('GROUP_B'),
            commonPrincipes: 'Mémantine (chlorhydrate de)',
            princepsReferenceName: 'AXURA',
          ),
        ];

        final grouped = ExplorerGroupingHelper.groupByCommonPrincipes(
          testItems,
        );

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
        final testItems = [
          GenericGroupEntity(
            groupId: GroupId('GROUP_MEMANTINE_10'),
            commonPrincipes: 'Mémantine (chlorhydrate de)',
            princepsReferenceName: 'AXURA 10 mg',
            princepsCisCode: CisCode(
              'CIS_10MG',
            ), // Different CIS codes (8 chars)
          ),
          GenericGroupEntity(
            groupId: GroupId('GROUP_MEMANTINE_20'),
            commonPrincipes: 'Mémantine (chlorhydrate de)',
            princepsReferenceName: 'AXURA 20 mg',
            princepsCisCode: CisCode(
              'CIS_20MG',
            ), // Different CIS codes (8 chars)
          ),
        ];

        final grouped = ExplorerGroupingHelper.groupByCommonPrincipes(
          testItems,
        );

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
        final testItems = [
          GenericGroupEntity(
            groupId: GroupId('GROUP_MIANSERINE_30'),
            commonPrincipes: 'Miansérine (chlorhydrate de)',
            princepsReferenceName: 'ATHYMIL 30 mg',
            princepsCisCode: CisCode('CIS_30MG'), // 8 chars
          ),
          GenericGroupEntity(
            groupId: GroupId('GROUP_MIANSERINE_60'),
            commonPrincipes: 'Miansérine (chlorhydrate de)',
            princepsReferenceName: 'ATHYMIL 60 mg',
            princepsCisCode: CisCode('CIS_60MG'), // 8 chars
          ),
        ];

        final grouped = ExplorerGroupingHelper.groupByCommonPrincipes(
          testItems,
        );

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
