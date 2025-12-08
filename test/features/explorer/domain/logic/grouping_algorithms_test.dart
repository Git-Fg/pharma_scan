import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/logic/grouping_algorithms.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';

GenericGroupEntity _group({
  required String groupId,
  required String princepsReferenceName,
  String? princepsCisCode,
  String commonPrincipes = 'PARACETAMOL',
}) {
  return GenericGroupEntity(
    groupId: GroupId.validated(groupId),
    princepsReferenceName: princepsReferenceName,
    princepsCisCode: princepsCisCode != null
        ? CisCode.validated(princepsCisCode)
        : null,
    commonPrincipes: commonPrincipes,
  );
}

void main() {
  group('normalizeCommonPrincipes', () {
    test('splits by + and comma, dedupes and sorts', () {
      final normalized = normalizeCommonPrincipes(
        ' Paracétamol + CODEINE , paracetamol ',
      );
      expect(normalized.toLowerCase(), contains('paracetamol'));
      expect(normalized.toLowerCase(), contains('codeine'));
    });

    test('keeps MEMANTINE normalized when already clean', () {
      final result = normalizeCommonPrincipes(
        'MEMANTINE',
      );
      expect(result, equals('MEMANTINE'));
    });

    test(
      'normalizePrincipleOptimal extracts MEMANTINE from salted string',
      () {
        final result = normalizePrincipleOptimal('MÉMANTINE (CHLORHYDRATE DE)');
        expect(result, equals('MEMANTINE'));
      },
    );
  });

  group('groupByCommonPrincipes', () {
    test('groups by princeps CIS hard link first', () {
      final a = _group(
        groupId: 'G1',
        princepsReferenceName: 'A',
        princepsCisCode: '00000100',
      );
      final b = _group(
        groupId: 'G2',
        princepsReferenceName: 'B',
        princepsCisCode: '00000100',
      );

      final result = groupByCommonPrincipes([a, b]);
      expect(result.length, 1);
      final cluster = result.first as GroupCluster;
      expect(cluster.groups.length, 2);
      expect(cluster.commonPrincipes, equals('PARACETAMOL'));
    });

    test('falls back to normalized principles and filters suspicious', () {
      final a = _group(
        groupId: 'G1',
        princepsReferenceName: 'ALPHA',
        commonPrincipes: 'X',
      );
      final b = _group(
        groupId: 'G2',
        princepsReferenceName: 'BETA',
        commonPrincipes: 'X',
      );

      final result = groupByCommonPrincipes([a, b]);
      expect(result.length, 2); // becomes UNIQUE because suspicious
      expect(result.any((e) => e is GroupCluster), isFalse);
    });

    test('formatPrincipes capitalizes and trims', () {
      final formatted = formatPrinciples(
        ' paracetamol , codeine ',
      );
      expect(formatted, equals('Paracetamol, Codeine'));
    });

    test('returns notDetermined when no data', () {
      final result = groupByCommonPrincipes([]);
      expect(result, isEmpty);

      final cluster = groupByCommonPrincipes([
        _group(
          groupId: 'G1',
          princepsReferenceName: Strings.notDetermined,
          commonPrincipes: '',
        ),
      ]);
      expect(cluster.first, isA<GenericGroupEntity>());
      expect(
        (cluster.first as GenericGroupEntity).princepsReferenceName,
        equals(Strings.notDetermined),
      );
    });

    test(
      'Mémantine with different dosages groups into a single cluster',
      () {
        final testItems = [
          GenericGroupEntity(
            groupId: GroupId('GROUP_MEMANTINE_10'),
            commonPrincipes: 'Mémantine (chlorhydrate de)',
            princepsReferenceName: 'AXURA',
            princepsCisCode: CisCode('12345678'),
          ),
          GenericGroupEntity(
            groupId: GroupId('GROUP_MEMANTINE_20'),
            commonPrincipes: 'Mémantine (chlorhydrate de)',
            princepsReferenceName: 'AXURA',
            princepsCisCode: CisCode('12345678'),
          ),
        ];

        final grouped = groupByCommonPrincipes(
          testItems,
        );

        expect(grouped.length, 1);
        final cluster = grouped.first as GroupCluster;
        expect(cluster.groups.length, 2);
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
      'Miansérine variants cluster together while preserving entries',
      () {
        final testItems = [
          GenericGroupEntity(
            groupId: GroupId('GROUP_MIANSERINE_30'),
            commonPrincipes: 'Miansérine (chlorhydrate de)',
            princepsReferenceName: 'ATHYMIL',
            princepsCisCode: CisCode('87654321'),
          ),
          GenericGroupEntity(
            groupId: GroupId('GROUP_MIANSERINE_60'),
            commonPrincipes: 'Miansérine (chlorhydrate de)',
            princepsReferenceName: 'ATHYMIL',
            princepsCisCode: CisCode('87654321'),
          ),
        ];

        final grouped = groupByCommonPrincipes(
          testItems,
        );

        expect(grouped.length, 1);
        final cluster = grouped.first as GroupCluster;
        expect(cluster.groups.length, 2);
      },
    );

    test(
      'Items sharing commonPrincipes still group even without princeps CIS',
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

        final grouped = groupByCommonPrincipes(
          testItems,
        );

        expect(grouped.length, 1);
        expect(grouped.first, isA<GroupCluster>());
      },
    );

    test(
      'Mémantine clusters even when princeps CIS codes differ',
      () {
        final testItems = [
          GenericGroupEntity(
            groupId: GroupId('GROUP_MEMANTINE_10'),
            commonPrincipes: 'Mémantine (chlorhydrate de)',
            princepsReferenceName: 'AXURA 10 mg',
            princepsCisCode: CisCode('CIS_10MG'),
          ),
          GenericGroupEntity(
            groupId: GroupId('GROUP_MEMANTINE_20'),
            commonPrincipes: 'Mémantine (chlorhydrate de)',
            princepsReferenceName: 'AXURA 20 mg',
            princepsCisCode: CisCode('CIS_20MG'),
          ),
        ];

        final grouped = groupByCommonPrincipes(
          testItems,
        );

        expect(grouped.length, 1);
        expect(grouped.first, isA<GroupCluster>());
      },
    );

    test(
      'Miansérine clusters even when princeps CIS codes differ',
      () {
        final testItems = [
          GenericGroupEntity(
            groupId: GroupId('GROUP_MIANSERINE_30'),
            commonPrincipes: 'Miansérine (chlorhydrate de)',
            princepsReferenceName: 'ATHYMIL 30 mg',
            princepsCisCode: CisCode('CIS_30MG'),
          ),
          GenericGroupEntity(
            groupId: GroupId('GROUP_MIANSERINE_60'),
            commonPrincipes: 'Miansérine (chlorhydrate de)',
            princepsReferenceName: 'ATHYMIL 60 mg',
            princepsCisCode: CisCode('CIS_60MG'),
          ),
        ];

        final grouped = groupByCommonPrincipes(
          testItems,
        );

        expect(grouped.length, 1);
        expect(grouped.first, isA<GroupCluster>());
      },
    );

    test(
      'Mémantine cluster includes all normalized entries and keeps displayName',
      () {
        final group1119 = GenericGroupEntity(
          groupId: GroupId.validated('1119'),
          commonPrincipes: 'MEMANTINE',
          princepsReferenceName: 'AXURA 10 mg, comprimé pelliculé',
        );

        final group1120 = GenericGroupEntity(
          groupId: GroupId.validated('1120'),
          commonPrincipes: 'MEMANTINE',
          princepsReferenceName: 'AXURA 20 mg, comprimé pelliculé',
        );

        final group1187 = GenericGroupEntity(
          groupId: GroupId.validated('1187'),
          commonPrincipes: 'MEMANTINE',
          princepsReferenceName: 'EBIXA 5 mg/pression, solution buvable',
        );

        final result = groupByCommonPrincipes(
          [group1119, group1120, group1187],
        );

        expect(result.length, equals(1));
        final cluster = result.first as GroupCluster;
        expect(cluster.groups.length, equals(3));
        expect(cluster.displayName.toUpperCase(), contains('MEMANTINE'));
      },
    );

    test(
      'Néfopam and Adriblastine must not cluster together (critical isolation)',
      () {
        final nefopamGroup = GenericGroupEntity(
          groupId: GroupId.validated('GROUP_NEFOPAM'),
          commonPrincipes: 'NEFOPAM',
          princepsReferenceName: 'ACUPAN',
        );

        final adriblastineGroup = GenericGroupEntity(
          groupId: GroupId.validated('GROUP_ADRIBLASTINE'),
          commonPrincipes: '',
          princepsReferenceName: 'ADRIBLASTINE',
        );

        final items = [nefopamGroup, adriblastineGroup];

        final result = groupByCommonPrincipes(items);

        expect(result.length, equals(2));

        final sameCluster = result.any((item) {
          if (item is GroupCluster) {
            final groupIds = item.groups.map((g) => g.groupId).toSet();
            return groupIds.contains('GROUP_NEFOPAM') &&
                groupIds.contains('GROUP_ADRIBLASTINE');
          }
          return false;
        });
        expect(sameCluster, isFalse);
      },
    );

    test(
      'Néfopam groups cluster together when principles are valid',
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

        final result = groupByCommonPrincipes(items);

        expect(result.length, equals(1));
        final cluster = result.first as GroupCluster;
        expect(cluster.groups.length, equals(2));
      },
    );

    test(
      'Adriblastine entries with empty principles stay separate',
      () {
        final adriblastineGroup1 = GenericGroupEntity(
          groupId: GroupId.validated('GROUP_ADRIBLASTINE_1'),
          commonPrincipes: '',
          princepsReferenceName: 'ADRIBLASTINE 10 mg',
        );

        final adriblastineGroup2 = GenericGroupEntity(
          groupId: GroupId.validated('GROUP_ADRIBLASTINE_2'),
          commonPrincipes: '',
          princepsReferenceName: 'ADRIBLASTINE 20 mg',
        );

        final items = [adriblastineGroup1, adriblastineGroup2];

        final result = groupByCommonPrincipes(items);

        expect(result.length, equals(2));
        final allAreSeparate = result.every(
          (item) => item is GenericGroupEntity,
        );
        expect(allAreSeparate, isTrue);
      },
    );

    test(
      'Real bug guard: empty principles stay unique while valid groups cluster',
      () {
        final testItems = [
          GenericGroupEntity(
            groupId: GroupId.validated('GROUP_NEFOPAM'),
            commonPrincipes: 'NÉFOPAM',
            princepsReferenceName: 'ACUPAN',
          ),
          GenericGroupEntity(
            groupId: GroupId.validated('GROUP_ADRIBLASTINE'),
            commonPrincipes: '',
            princepsReferenceName: 'ADRIBLASTINE',
          ),
          GenericGroupEntity(
            groupId: GroupId.validated('GROUP_ANAFRANIL'),
            commonPrincipes: '',
            princepsReferenceName: 'ANAFRANIL',
          ),
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

        final grouped = groupByCommonPrincipes(
          testItems,
        );

        final emptyPrincipesItems = grouped.where((item) {
          if (item is GenericGroupEntity) {
            return item.commonPrincipes.isEmpty;
          } else if (item is GroupCluster) {
            return item.commonPrincipes.isEmpty ||
                item.commonPrincipes == 'Non déterminé';
          }
          return false;
        }).toList();

        for (final item in emptyPrincipesItems) {
          expect(item, isA<GenericGroupEntity>());
        }

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

        expect(paracetamolClusters.length, greaterThan(0));
      },
    );

    test(
      'Néfopam salt stays isolated from Adriblastine when principles are empty',
      () {
        final testItems = [
          GenericGroupEntity(
            groupId: GroupId('GROUP_NEFOPAM_SALT'),
            commonPrincipes: '',
            princepsReferenceName: 'ACUPAN',
          ),
          GenericGroupEntity(
            groupId: GroupId.validated('GROUP_ADRIBLASTINE'),
            commonPrincipes: '',
            princepsReferenceName: 'ADRIBLASTINE',
          ),
        ];

        final grouped = groupByCommonPrincipes(
          testItems,
        );

        expect(grouped.length, 2);

        final sameCluster = grouped.any((item) {
          if (item is GroupCluster) {
            final groupIds = item.groups.map((g) => g.groupId).toSet();
            return groupIds.contains('GROUP_NEFOPAM_SALT') &&
                groupIds.contains('GROUP_ADRIBLASTINE');
          }
          return false;
        });

        expect(sameCluster, isFalse);
      },
    );
  });
}
