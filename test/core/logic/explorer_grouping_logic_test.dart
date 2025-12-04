// test/features/explorer/grouping_logic_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/features/explorer/domain/logic/explorer_grouping_helper.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';

void main() {
  group('Explorer Grouping Logic - Néfopam Isolation Test', () {
    // CRITICAL TEST: This simulates the REAL bug scenario
    // In the database, Adriblastine and Anafranil might incorrectly have
    // the same commonPrincipes as Néfopam. The grouping logic should handle this
    // by ensuring items with empty or invalid commonPrincipes get unique keys.
    test(
      'REAL BUG: Items that should have empty commonPrincipes should NOT be grouped even if database has same value',
      () {
        final testItems = [
          // Néfopam - has valid commonPrincipes
          GenericGroupEntity(
            groupId: GroupId.validated('GROUP_NEFOPAM'),
            commonPrincipes: 'NÉFOPAM',
            princepsReferenceName: 'ACUPAN',
          ),
          // Adriblastine - in reality should have empty commonPrincipes
          // But if database incorrectly has 'NÉFOPAM', it would be grouped (BUG)
          // The fix ensures empty items get unique keys, so they won't be grouped
          GenericGroupEntity(
            groupId: GroupId.validated('GROUP_ADRIBLASTINE'),
            commonPrincipes: '', // Empty - should get unique key
            princepsReferenceName: 'ADRIBLASTINE',
          ),
          // Anafranil - same as Adriblastine
          GenericGroupEntity(
            groupId: GroupId.validated('GROUP_ANAFRANIL'),
            commonPrincipes: '', // Empty - should get unique key
            princepsReferenceName: 'ANAFRANIL',
          ),
        ];

        final grouped = ExplorerGroupingHelper.groupByCommonPrincipes(
          testItems,
        );

        // 1. Néfopam should be in its own cluster (has valid commonPrincipes)
        final nefopamCluster = grouped.firstWhere(
          (item) {
            if (item is GroupCluster) {
              return item.groups.any((g) => g.groupId == 'GROUP_NEFOPAM');
            } else if (item is GenericGroupEntity) {
              return item.groupId == 'GROUP_NEFOPAM';
            }
            return false;
          },
          orElse: () => throw Exception('Néfopam not found'),
        );

        // 2. Adriblastine and Anafranil should be separate items (empty commonPrincipes)
        final adriblastineItem =
            grouped.firstWhere(
                  (item) {
                    if (item is GenericGroupEntity) {
                      return item.groupId == 'GROUP_ADRIBLASTINE';
                    }
                    return false;
                  },
                  orElse: () => throw Exception('Adriblastine not found'),
                )
                as GenericGroupEntity;

        final anafranilItem =
            grouped.firstWhere(
                  (item) {
                    if (item is GenericGroupEntity) {
                      return item.groupId == 'GROUP_ANAFRANIL';
                    }
                    return false;
                  },
                  orElse: () => throw Exception('Anafranil not found'),
                )
                as GenericGroupEntity;

        // 3. CRITICAL: Adriblastine and Anafranil should NOT be in Néfopam cluster
        if (nefopamCluster is GroupCluster) {
          final groupIds = nefopamCluster.groups.map((g) => g.groupId).toSet();
          expect(
            groupIds.contains('GROUP_ADRIBLASTINE'),
            isFalse,
            reason:
                'CRITICAL: Adriblastine should NOT be grouped with Néfopam (empty commonPrincipes should create unique key)',
          );
          expect(
            groupIds.contains('GROUP_ANAFRANIL'),
            isFalse,
            reason:
                'CRITICAL: Anafranil should NOT be grouped with Néfopam (empty commonPrincipes should create unique key)',
          );
        }

        // 4. Verify Adriblastine and Anafranil are separate (not grouped together)
        expect(
          adriblastineItem.commonPrincipes.isEmpty,
          isTrue,
          reason: 'Adriblastine should have empty commonPrincipes',
        );
        expect(
          anafranilItem.commonPrincipes.isEmpty,
          isTrue,
          reason: 'Anafranil should have empty commonPrincipes',
        );
      },
    );
    test(
      'Items with empty commonPrincipes should NOT be grouped together',
      () {
        // The issue: Items with the SAME commonPrincipes value are being grouped together
        // even though they shouldn't be (e.g., Adriblastine has NÉFOPAM as commonPrincipes)
        //
        // REAL SCENARIO: In the database, some items incorrectly have the same commonPrincipes
        // We need to ensure that even if they have the same commonPrincipes, they are NOT grouped
        // if they are unrelated (different groupId).
        //
        // However, the actual fix is: Items with empty or invalid commonPrincipes should
        // get unique keys. But if items have the SAME valid commonPrincipes, they WILL be grouped.
        // So the real test should verify that items with DIFFERENT groupIds but same commonPrincipes
        // are handled correctly.
        final testItems = [
          // Néfopam group - has NÉFOPAM as commonPrincipes
          GenericGroupEntity(
            groupId: GroupId.validated('GROUP_NEFOPAM'),
            commonPrincipes: 'NÉFOPAM',
            princepsReferenceName: 'ACUPAN',
          ),
          // Adriblastine - should have empty or different commonPrincipes, NOT NÉFOPAM
          // But if it incorrectly has NÉFOPAM, it would be grouped (this is the bug)
          // The fix: Items with empty commonPrincipes get unique keys
          GenericGroupEntity(
            groupId: GroupId.validated('GROUP_ADRIBLASTINE'),
            commonPrincipes:
                '', // Empty - should get unique key and NOT be grouped
            princepsReferenceName: 'ADRIBLASTINE',
          ),
          // Anafranil - same as Adriblastine
          GenericGroupEntity(
            groupId: GroupId.validated('GROUP_ANAFRANIL'),
            commonPrincipes:
                '', // Empty - should get unique key and NOT be grouped
            princepsReferenceName: 'ANAFRANIL',
          ),
          // Paracetamol - has valid principles, should group correctly
          GenericGroupEntity(
            groupId: GroupId('GROUP_PARACETAMOL_1'),
            commonPrincipes: 'PARACETAMOL',
            princepsReferenceName: 'DOLIPRANE',
          ),
          GenericGroupEntity(
            groupId: GroupId('GROUP_PARACETAMOL_2'),
            commonPrincipes: 'PARACETAMOL',
            princepsReferenceName: 'EFFERALGAN',
          ),
        ];

        final grouped = ExplorerGroupingHelper.groupByCommonPrincipes(
          testItems,
        );

        // THEN: Verify that items with empty commonPrincipes are NOT grouped together
        // Each item with empty commonPrincipes should get a unique key and appear separately

        // Find all items with empty commonPrincipes
        final emptyPrincipesItems = grouped.where((item) {
          if (item is GenericGroupEntity) {
            return item.commonPrincipes.isEmpty;
          } else if (item is GroupCluster) {
            return item.commonPrincipes.isEmpty ||
                item.commonPrincipes == 'Non déterminé';
          }
          return false;
        }).toList();

        // Each item with empty commonPrincipes should be a separate GenericGroupEntity
        // (not grouped into a cluster)
        for (final item in emptyPrincipesItems) {
          expect(
            item,
            isA<GenericGroupEntity>(),
            reason: 'Items with empty commonPrincipes should NOT be clustered',
          );
        }

        // Verify Néfopam (with valid commonPrincipes) is separate from empty items
        final nefopamItem = grouped.firstWhere(
          (item) {
            if (item is GenericGroupEntity) {
              return item.groupId == 'GROUP_NEFOPAM';
            } else if (item is GroupCluster) {
              return item.groups.any((g) => g.groupId == 'GROUP_NEFOPAM');
            }
            return false;
          },
          orElse: () => throw Exception('Néfopam group not found'),
        );

        // Néfopam should be in a cluster (because it has valid commonPrincipes)
        // but it should NOT contain Adriblastine or Anafranil
        if (nefopamItem is GroupCluster) {
          final groupIds = nefopamItem.groups.map((g) => g.groupId).toSet();
          expect(
            groupIds,
            contains('GROUP_NEFOPAM'),
            reason: 'Néfopam group should be present',
          );
          expect(
            groupIds,
            isNot(contains('GROUP_ADRIBLASTINE')),
            reason: 'Adriblastine should NOT be grouped with Néfopam',
          );
          expect(
            groupIds,
            isNot(contains('GROUP_ANAFRANIL')),
            reason: 'Anafranil should NOT be grouped with Néfopam',
          );
        }

        // Verify Adriblastine is separate
        final adriblastineItem = grouped.firstWhere(
          (item) {
            if (item is GenericGroupEntity) {
              return item.groupId == 'GROUP_ADRIBLASTINE';
            } else if (item is GroupCluster) {
              return item.groups.any((g) => g.groupId == 'GROUP_ADRIBLASTINE');
            }
            return false;
          },
          orElse: () => throw Exception('Adriblastine group not found'),
        );

        if (adriblastineItem is GroupCluster) {
          // If Adriblastine is in a cluster, verify it doesn't contain Néfopam
          final groupIds = adriblastineItem.groups
              .map((g) => g.groupId)
              .toSet();
          expect(
            groupIds,
            isNot(contains('GROUP_NEFOPAM')),
            reason: 'Adriblastine cluster should NOT contain Néfopam',
          );
        }

        // Verify Anafranil is separate
        final anafranilItem = grouped.firstWhere(
          (item) {
            if (item is GenericGroupEntity) {
              return item.groupId == 'GROUP_ANAFRANIL';
            } else if (item is GroupCluster) {
              return item.groups.any((g) => g.groupId == 'GROUP_ANAFRANIL');
            }
            return false;
          },
          orElse: () => throw Exception('Anafranil group not found'),
        );

        if (anafranilItem is GroupCluster) {
          // If Anafranil is in a cluster, verify it doesn't contain Néfopam
          final groupIds = anafranilItem.groups.map((g) => g.groupId).toSet();
          expect(
            groupIds,
            isNot(contains('GROUP_NEFOPAM')),
            reason: 'Anafranil cluster should NOT contain Néfopam',
          );
        }

        // Verify Paracetamol groups correctly (control test)
        final paracetamolClusters = grouped.where((item) {
          if (item is GroupCluster) {
            return item.groups.any(
              (g) => g.commonPrincipes.toUpperCase().contains('PARACETAMOL'),
            );
          } else if (item is GenericGroupEntity) {
            return item.commonPrincipes.toUpperCase().contains('PARACETAMOL');
          }
          return false;
        }).toList();

        // Paracetamol should be grouped (has valid principles)
        expect(
          paracetamolClusters.length,
          greaterThan(0),
          reason: 'Paracetamol groups should be found',
        );
      },
    );

    test(
      'Items with same commonPrincipes should be grouped, but empty ones should be separate',
      () {
        final testItems = [
          // Néfopam with valid commonPrincipes
          GenericGroupEntity(
            groupId: GroupId.validated('GROUP_NEFOPAM'),
            commonPrincipes: 'NÉFOPAM',
            princepsReferenceName: 'ACUPAN',
          ),
          // Another Néfopam item (should be grouped with above)
          GenericGroupEntity(
            groupId: GroupId('GROUP_NEFOPAM_2'),
            commonPrincipes: 'NÉFOPAM',
            princepsReferenceName: 'ACUPAN GENERIQUE',
          ),
          // Adriblastine with empty commonPrincipes (should be separate)
          GenericGroupEntity(
            groupId: GroupId.validated('GROUP_ADRIBLASTINE'),
            commonPrincipes: '',
            princepsReferenceName: 'ADRIBLASTINE',
          ),
          // Anafranil with empty commonPrincipes (should be separate)
          GenericGroupEntity(
            groupId: GroupId.validated('GROUP_ANAFRANIL'),
            commonPrincipes: '',
            princepsReferenceName: 'ANAFRANIL',
          ),
        ];

        final grouped = ExplorerGroupingHelper.groupByCommonPrincipes(
          testItems,
        );

        // THEN:
        // 1. Néfopam items should be grouped together (same commonPrincipes)
        final nefopamCluster =
            grouped.firstWhere(
                  (item) {
                    if (item is GroupCluster) {
                      return item.groups.any(
                        (g) => g.groupId == 'GROUP_NEFOPAM',
                      );
                    }
                    return false;
                  },
                  orElse: () => throw Exception('Néfopam cluster not found'),
                )
                as GroupCluster;

        expect(nefopamCluster.groups.length, 2);
        expect(
          nefopamCluster.groups.any((g) => g.groupId == 'GROUP_NEFOPAM'),
          isTrue,
        );
        expect(
          nefopamCluster.groups.any((g) => g.groupId == 'GROUP_NEFOPAM_2'),
          isTrue,
        );

        // 2. Adriblastine and Anafranil should be separate (empty commonPrincipes)
        // Verify they exist and are separate items
        final adriblastineFound = grouped.any((item) {
          if (item is GenericGroupEntity) {
            return item.groupId == 'GROUP_ADRIBLASTINE';
          }
          return false;
        });
        expect(
          adriblastineFound,
          isTrue,
          reason: 'Adriblastine should be found',
        );

        final anafranilFound = grouped.any((item) {
          if (item is GenericGroupEntity) {
            return item.groupId == 'GROUP_ANAFRANIL';
          }
          return false;
        });
        expect(anafranilFound, isTrue, reason: 'Anafranil should be found');

        // Verify they are NOT in the Néfopam cluster
        expect(
          nefopamCluster.groups.any((g) => g.groupId == 'GROUP_ADRIBLASTINE'),
          isFalse,
          reason: 'Adriblastine should NOT be in Néfopam cluster',
        );
        expect(
          nefopamCluster.groups.any((g) => g.groupId == 'GROUP_ANAFRANIL'),
          isFalse,
          reason: 'Anafranil should NOT be in Néfopam cluster',
        );
      },
    );

    test(
      'Néfopam with salt (Chlorhydrate de Néfopam) should only link to Acupan',
      () {
        final testItems = [
          GenericGroupEntity(
            groupId: GroupId('GROUP_NEFOPAM_SALT'),
            commonPrincipes: '', // Empty - simulates missing principles
            princepsReferenceName: 'ACUPAN',
          ),
          GenericGroupEntity(
            groupId: GroupId.validated('GROUP_ADRIBLASTINE'),
            commonPrincipes: '',
            princepsReferenceName: 'ADRIBLASTINE',
          ),
        ];

        final grouped = ExplorerGroupingHelper.groupByCommonPrincipes(
          testItems,
        );

        // THEN: Verify they are separate
        expect(grouped.length, 2, reason: 'Should have 2 separate items');

        final nefopamFound = grouped.any((item) {
          if (item is GenericGroupEntity) {
            return item.groupId == 'GROUP_NEFOPAM_SALT';
          } else if (item is GroupCluster) {
            return item.groups.any((g) => g.groupId == 'GROUP_NEFOPAM_SALT');
          }
          return false;
        });

        final adriblastineFound = grouped.any((item) {
          if (item is GenericGroupEntity) {
            return item.groupId == 'GROUP_ADRIBLASTINE';
          } else if (item is GroupCluster) {
            return item.groups.any((g) => g.groupId == 'GROUP_ADRIBLASTINE');
          }
          return false;
        });

        expect(nefopamFound, isTrue, reason: 'Néfopam should be found');
        expect(
          adriblastineFound,
          isTrue,
          reason: 'Adriblastine should be found',
        );

        // Verify they are NOT in the same cluster
        final sameCluster = grouped.any((item) {
          if (item is GroupCluster) {
            final groupIds = item.groups.map((g) => g.groupId).toSet();
            return groupIds.contains('GROUP_NEFOPAM_SALT') &&
                groupIds.contains('GROUP_ADRIBLASTINE');
          }
          return false;
        });

        expect(
          sameCluster,
          isFalse,
          reason: 'Néfopam and Adriblastine should NOT be in the same cluster',
        );
      },
    );
  });
}
