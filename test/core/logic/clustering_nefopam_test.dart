// test/features/explorer/clustering_néfopam_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/features/explorer/domain/logic/explorer_grouping_helper.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';

void main() {
  group('Néfopam/Adriblastine Edge Case - Critical Isolation Test', () {
    test(
      'CRITICAL: Néfopam and Adriblastine should NOT cluster together',
      () {
        final nefopamGroup = GenericGroupEntity(
          groupId: GroupId.validated('GROUP_NEFOPAM'),
          commonPrincipes: 'NEFOPAM',
          princepsReferenceName: 'ACUPAN',
        );

        final adriblastineGroup = GenericGroupEntity(
          groupId: GroupId.validated('GROUP_ADRIBLASTINE'),
          commonPrincipes: '', // Empty - should get unique key
          princepsReferenceName: 'ADRIBLASTINE',
        );

        final items = [nefopamGroup, adriblastineGroup];

        final result = ExplorerGroupingHelper.groupByCommonPrincipes(items);

        expect(
          result.length,
          equals(2),
          reason:
              'CRITICAL: Néfopam and Adriblastine must remain separate groups. '
              'This verifies the "Suspicious Data" check prevents incorrect clustering.',
        );

        final nefopamFound = result.any((item) {
          if (item is GenericGroupEntity) {
            return item.groupId == 'GROUP_NEFOPAM';
          } else if (item is GroupCluster) {
            return item.groups.any((g) => g.groupId == 'GROUP_NEFOPAM');
          }
          return false;
        });
        expect(nefopamFound, isTrue, reason: 'Néfopam should be found');

        final adriblastineFound = result.any((item) {
          if (item is GenericGroupEntity) {
            return item.groupId == 'GROUP_ADRIBLASTINE';
          } else if (item is GroupCluster) {
            return item.groups.any((g) => g.groupId == 'GROUP_ADRIBLASTINE');
          }
          return false;
        });
        expect(
          adriblastineFound,
          isTrue,
          reason: 'Adriblastine should be found',
        );

        final sameCluster = result.any((item) {
          if (item is GroupCluster) {
            final groupIds = item.groups.map((g) => g.groupId).toSet();
            return groupIds.contains('GROUP_NEFOPAM') &&
                groupIds.contains('GROUP_ADRIBLASTINE');
          }
          return false;
        });
        expect(
          sameCluster,
          isFalse,
          reason:
              'CRITICAL: Néfopam and Adriblastine must NOT be in the same cluster. '
              'This is a critical edge case from DOMAIN_LOGIC.md.',
        );
      },
    );

    test(
      'Néfopam with valid commonPrincipes should cluster with other Néfopam groups',
      () {
        final nefopamGroup1 = GenericGroupEntity(
          groupId: GroupId.validated('GROUP_NEFOPAM_1'),
          commonPrincipes: 'NEFOPAM',
          princepsReferenceName: 'ACUPAN 20 mg',
        );

        final nefopamGroup2 = GenericGroupEntity(
          groupId: GroupId.validated('GROUP_NEFOPAM_2'),
          commonPrincipes: 'NEFOPAM',
          princepsReferenceName: 'ACUPAN 30 mg',
        );

        final items = [nefopamGroup1, nefopamGroup2];

        final result = ExplorerGroupingHelper.groupByCommonPrincipes(items);

        expect(
          result.length,
          equals(1),
          reason: 'Néfopam groups with same commonPrincipes should cluster',
        );

        expect(
          result.first,
          isA<GroupCluster>(),
          reason: 'Result should be a GroupCluster',
        );

        final cluster = result.first as GroupCluster;
        expect(
          cluster.groups.length,
          equals(2),
          reason: 'Cluster should contain both Néfopam groups',
        );
      },
    );

    test(
      'Adriblastine with empty commonPrincipes should remain separate',
      () {
        final adriblastineGroup1 = GenericGroupEntity(
          groupId: GroupId.validated('GROUP_ADRIBLASTINE_1'),
          commonPrincipes: '', // Empty
          princepsReferenceName: 'ADRIBLASTINE 10 mg',
        );

        final adriblastineGroup2 = GenericGroupEntity(
          groupId: GroupId.validated('GROUP_ADRIBLASTINE_2'),
          commonPrincipes: '', // Empty
          princepsReferenceName: 'ADRIBLASTINE 20 mg',
        );

        final items = [adriblastineGroup1, adriblastineGroup2];

        final result = ExplorerGroupingHelper.groupByCommonPrincipes(items);

        expect(
          result.length,
          equals(2),
          reason:
              'Items with empty commonPrincipes should NOT be clustered together',
        );

        // Verify both are separate GenericGroupEntity instances
        final allAreSeparate = result.every(
          (item) => item is GenericGroupEntity,
        );
        expect(
          allAreSeparate,
          isTrue,
          reason: 'All items with empty commonPrincipes should be separate',
        );
      },
    );
  });
}
