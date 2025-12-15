import 'package:pharma_scan/core/domain/models/generic_group_entity.dart';
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

/// Builds a letter index for the sidebar navigation.
Map<String, int> _buildLetterIndex(
  List<GenericGroupEntity> items,
  List<String> allowedLetters,
) {
  final allowedSet = allowedLetters.toSet();
  final letterIndex = <String, int>{};

  for (final (index, item) in items.indexed) {
    final candidate = item.princepsReferenceName.isNotEmpty
        ? item.princepsReferenceName
        : item.commonPrincipes;

    final normalized = candidate.trim().toUpperCase();
    if (normalized.isEmpty) continue;

    final letter = RegExp('^[0-9]').hasMatch(normalized) ? '#' : normalized[0];
    if (!allowedSet.contains(letter)) continue;

    letterIndex.putIfAbsent(letter, () => index);
  }

  return letterIndex;
}

@Riverpod(keepAlive: true)
Future<({List<GenericGroupEntity> groupedItems, Map<String, int> letterIndex})>
groupedExplorerContent(
  Ref ref,
) async {
  final groups = await ref.watch(genericGroupsProvider.future);

  if (groups.items.isEmpty) {
    return (
      groupedItems: List<GenericGroupEntity>.empty(),
      letterIndex: <String, int>{},
    );
  }

  // Groups are already provided by the DB, no client-side clustering needed
  final letterIndex = _buildLetterIndex(groups.items, _sidebarLetters);

  return (groupedItems: groups.items, letterIndex: letterIndex);
}
