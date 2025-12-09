import 'package:flutter/foundation.dart';
import 'package:pharma_scan/features/explorer/domain/logic/grouping_algorithms.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/generic_groups_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'grouped_content_provider.g.dart';

const _sidebarLetters = [
  '#',
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'J',
  'K',
  'L',
  'M',
  'N',
  'P',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];

({List<Object> groupedItems, Map<String, int> letterIndex})
_processGroupingInBackground(List<GenericGroupEntity> items) {
  if (items.isEmpty) {
    return (
      groupedItems: List<Object>.empty(),
      letterIndex: <String, int>{},
    );
  }

  final groupedItems = groupByCommonPrincipes(items);
  final letterIndex = buildLetterIndex(groupedItems, _sidebarLetters);

  return (groupedItems: groupedItems, letterIndex: letterIndex);
}

@riverpod
Future<({List<Object> groupedItems, Map<String, int> letterIndex})>
groupedExplorerContent(
  Ref ref,
) async {
  final groups = await ref.watch(genericGroupsProvider.future);

  if (groups.items.isEmpty) {
    return (
      groupedItems: List<Object>.empty(),
      letterIndex: <String, int>{},
    );
  }

  return compute(_processGroupingInBackground, groups.items);
}
