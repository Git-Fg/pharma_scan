// test/features/explorer/clustering_néfopam_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/explorer_grouping_helper.dart';

void main() {
  group('Néfopam/Adriblastine Edge Case - Critical Isolation Test', () {
    test(
      'CRITICAL: Néfopam and Adriblastine should NOT cluster together',
      () {
        // GIVEN: Néfopam and Adriblastine groups
        // Reference: docs/DOMAIN_LOGIC.md - "Suspicious Data" check
        // These medications should remain separate even if they accidentally
        // share a raw string in the source data
        const nefopamGroup = GenericGroupEntity(
          groupId: 'GROUP_NEFOPAM',
          commonPrincipes: 'NEFOPAM',
          princepsReferenceName: 'ACUPAN',
        );

        const adriblastineGroup = GenericGroupEntity(
          groupId: 'GROUP_ADRIBLASTINE',
          commonPrincipes: '', // Empty - should get unique key
          princepsReferenceName: 'ADRIBLASTINE',
        );

        final items = [nefopamGroup, adriblastineGroup];

        // WHEN: Apply clustering logic
        final result = ExplorerGroupingHelper.groupByCommonPrincipes(items);

        // THEN: They should remain separate (NOT clustered)
        expect(
          result.length,
          equals(2),
          reason:
              'CRITICAL: Néfopam and Adriblastine must remain separate groups. '
              'This verifies the "Suspicious Data" check prevents incorrect clustering.',
        );

        // Verify Néfopam is separate
        final nefopamFound = result.any((item) {
          if (item is GenericGroupEntity) {
            return item.groupId == 'GROUP_NEFOPAM';
          } else if (item is GroupCluster) {
            return item.groups.any((g) => g.groupId == 'GROUP_NEFOPAM');
          }
          return false;
        });
        expect(nefopamFound, isTrue, reason: 'Néfopam should be found');

        // Verify Adriblastine is separate
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

        // CRITICAL: Verify they are NOT in the same cluster
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
        // GIVEN: Multiple Néfopam groups with same commonPrincipes
        const nefopamGroup1 = GenericGroupEntity(
          groupId: 'GROUP_NEFOPAM_1',
          commonPrincipes: 'NEFOPAM',
          princepsReferenceName: 'ACUPAN 20 mg',
        );

        const nefopamGroup2 = GenericGroupEntity(
          groupId: 'GROUP_NEFOPAM_2',
          commonPrincipes: 'NEFOPAM',
          princepsReferenceName: 'ACUPAN 30 mg',
        );

        final items = [nefopamGroup1, nefopamGroup2];

        // WHEN: Apply clustering logic
        final result = ExplorerGroupingHelper.groupByCommonPrincipes(items);

        // THEN: They should be clustered together (same commonPrincipes)
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
        // GIVEN: Multiple items with empty commonPrincipes
        const adriblastineGroup1 = GenericGroupEntity(
          groupId: 'GROUP_ADRIBLASTINE_1',
          commonPrincipes: '', // Empty
          princepsReferenceName: 'ADRIBLASTINE 10 mg',
        );

        const adriblastineGroup2 = GenericGroupEntity(
          groupId: 'GROUP_ADRIBLASTINE_2',
          commonPrincipes: '', // Empty
          princepsReferenceName: 'ADRIBLASTINE 20 mg',
        );

        final items = [adriblastineGroup1, adriblastineGroup2];

        // WHEN: Apply clustering logic
        final result = ExplorerGroupingHelper.groupByCommonPrincipes(items);

        // THEN: Items with empty commonPrincipes should remain separate
        // (each gets a unique key)
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
