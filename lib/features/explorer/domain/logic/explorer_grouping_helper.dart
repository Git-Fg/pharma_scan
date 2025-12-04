// Testable grouping logic extracted from ExplorerContentList
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';

/// Cluster class for grouping (matches _GroupCluster from ExplorerContentList)
class GroupCluster {
  const GroupCluster({
    required this.groups,
    required this.commonPrincipes,
    required this.displayName,
    required this.sortKey,
  });

  final List<GenericGroupEntity> groups;
  final String commonPrincipes;
  final String displayName;
  final String sortKey;
}

/// Testable helper class for grouping logic
class ExplorerGroupingHelper {
  /// Normalizes commonPrincipes for comparison using optimal normalization.
  static String normalizeCommonPrincipes(String commonPrincipes) {
    if (commonPrincipes.isEmpty) return '';

    // 1. Split by "+" (associations) if present, otherwise by comma.
    final rawList = commonPrincipes.contains('+')
        ? commonPrincipes.split('+')
        : commonPrincipes.split(',');

    // 2. Normalize each principle individually, deduplicate and sort.
    final normalizedSet = rawList
        .map((p) => normalizePrincipleOptimal(p.trim()))
        .where((p) => p.isNotEmpty)
        .toSet();

    final normalizedList = normalizedSet.toList()..sort();

    return normalizedList.join(', ').trim();
  }

  /// Formats principles string for display by capitalizing the first letter.
  static String formatPrinciples(String principles) {
    if (principles.isEmpty) return principles;

    return principles
        .split(',')
        .map((p) {
          final trimmed = p.trim();
          if (trimmed.isEmpty) return trimmed;
          return trimmed[0].toUpperCase() +
              (trimmed.length > 1 ? trimmed.substring(1).toLowerCase() : '');
        })
        .where((p) => p.isNotEmpty)
        .join(', ');
  }

  /// Calculates the dominant princeps name from a list of groups.
  /// The dominant princeps is the most frequent `princepsReferenceName` in the cluster.
  /// In case of ties, returns the first one alphabetically.
  static String _calculateDominantPrinceps(List<GenericGroupEntity> groups) {
    if (groups.isEmpty) return Strings.notDetermined;
    if (groups.length == 1) {
      final name = groups.first.princepsReferenceName;
      return name.isNotEmpty ? name : Strings.notDetermined;
    }

    // Count occurrences of each princepsReferenceName
    final counts = <String, int>{};
    for (final group in groups) {
      final name = group.princepsReferenceName.trim();
      if (name.isNotEmpty) {
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }

    if (counts.isEmpty) return Strings.notDetermined;

    // Sort by frequency (descending), then alphabetically (ascending) for tie-breaker
    final sortedEntries = counts.entries.toList()
      ..sort((a, b) {
        // First sort by frequency (descending)
        final frequencyCompare = b.value.compareTo(a.value);
        if (frequencyCompare != 0) return frequencyCompare;
        // If frequencies are equal, sort alphabetically (ascending)
        return normalizePrincipleOptimal(
          a.key,
        ).compareTo(normalizePrincipleOptimal(b.key));
      });

    return sortedEntries.first.key;
  }

  /// Groups items by their commonPrincipes using a hybrid clustering strategy.
  /// Priority order:
  /// 1. Princeps CIS code hard link
  /// 2. Text normalization (soft link, fallback)
  /// This is the testable version of the grouping logic.
  static List<Object> groupByCommonPrincipes(List<GenericGroupEntity> items) {
    if (items.isEmpty) return [];

    // ===== PHASE 0: BUILD CIS-TO-PRINCIPLE MAP (Hard Link) =====
    // Map each princeps CIS code to a normalized principle name.
    // If multiple principles map to one CIS, prefer the shortest/cleanest one.
    final cisToPrincipleMap = <String, String>{};
    for (final item in items) {
      if (item.princepsCisCode != null && item.commonPrincipes.isNotEmpty) {
        final normalized = normalizeCommonPrincipes(item.commonPrincipes);
        if (normalized.length > 2) {
          final cisCodeString = item.princepsCisCode!.toString();
          final existing = cisToPrincipleMap[cisCodeString];
          if (existing == null) {
            // First mapping for this CIS
            cisToPrincipleMap[cisCodeString] = normalized;
          } else {
            // Conflict resolution: prefer shorter/cleaner principle name
            if (normalized.length < existing.length ||
                (normalized.length == existing.length &&
                    normalized.compareTo(existing) < 0)) {
              cisToPrincipleMap[cisCodeString] = normalized;
            }
          }
        }
      }
    }

    // ===== PHASE 1: GROUPING =====
    final commonPrincipesCounts = <String, int>{};
    final commonPrincipesToGroupIds = <String, Set<String>>{};

    for (final item in items) {
      String? groupingKey;
      if (item.princepsCisCode != null &&
          cisToPrincipleMap.containsKey(item.princepsCisCode!.toString())) {
        groupingKey = cisToPrincipleMap[item.princepsCisCode!.toString()];
      } else if (item.commonPrincipes.isNotEmpty) {
        groupingKey = normalizeCommonPrincipes(item.commonPrincipes);
      }

      if (groupingKey != null && groupingKey.length > 2) {
        commonPrincipesCounts[groupingKey] =
            (commonPrincipesCounts[groupingKey] ?? 0) + 1;
        commonPrincipesToGroupIds
            .putIfAbsent(
              groupingKey,
              () => <String>{},
            )
            .add(item.groupId.toString());
      }
    }

    final suspiciousPrincipes = <String>{};

    for (final entry in commonPrincipesToGroupIds.entries) {
      if (entry.value.length > 1) {
        final isSinglePrinciple = !entry.key.contains(',');
        if (isSinglePrinciple && entry.key.length >= 4) {
          continue;
        }

        final itemsWithSamePrincipes = items.where((item) {
          String? groupingKey;
          if (item.princepsCisCode != null &&
              cisToPrincipleMap.containsKey(item.princepsCisCode!.toString())) {
            groupingKey = cisToPrincipleMap[item.princepsCisCode!.toString()];
          } else if (item.commonPrincipes.isNotEmpty) {
            groupingKey = normalizeCommonPrincipes(item.commonPrincipes);
          }
          return groupingKey != null &&
              groupingKey == entry.key &&
              groupingKey.length > 2;
        }).toList();

        final normalizedPrinceps = itemsWithSamePrincipes
            .map(
              (item) => normalizePrincipleOptimal(item.princepsReferenceName),
            )
            .toList();

        if (entry.value.length > 2) {
          final uniquePrinceps = normalizedPrinceps.toSet();

          var allShareCommonPrefix = false;
          if (uniquePrinceps.length > 1) {
            // Find the longest common prefix across all names
            final first = uniquePrinceps.first;
            var commonPrefixLength = 0;
            if (first.length >= 4) {
              for (var len = 4; len <= first.length; len++) {
                final prefix = first.substring(0, len);
                if (uniquePrinceps.every(
                  (name) =>
                      name.length >= len && name.substring(0, len) == prefix,
                )) {
                  commonPrefixLength = len;
                } else {
                  break;
                }
              }
            }
            allShareCommonPrefix = commonPrefixLength >= 4;
          }

          if (uniquePrinceps.length > 3 && !allShareCommonPrefix) {
            suspiciousPrincipes.add(entry.key);
          } else if (!allShareCommonPrefix) {
            var hasVeryDifferentNames = false;
            for (var i = 0; i < normalizedPrinceps.length; i++) {
              for (var j = i + 1; j < normalizedPrinceps.length; j++) {
                final name1 = normalizedPrinceps[i];
                final name2 = normalizedPrinceps[j];
                final minLen = name1.length < name2.length
                    ? name1.length
                    : name2.length;
                if (minLen >= 4) {
                  final prefix1 = name1.substring(0, 4);
                  final prefix2 = name2.substring(0, 4);
                  if (prefix1 != prefix2 &&
                      !name1.contains(prefix2) &&
                      !name2.contains(prefix1)) {
                    hasVeryDifferentNames = true;
                    break;
                  }
                } else {
                  if (name1 != name2 &&
                      !name1.contains(name2) &&
                      !name2.contains(name1)) {
                    hasVeryDifferentNames = true;
                    break;
                  }
                }
              }
              if (hasVeryDifferentNames) break;
            }

            if (hasVeryDifferentNames) {
              suspiciousPrincipes.add(entry.key);
            }
          }
        }
      }
    }

    final groupedByPrincipes = <String, List<GenericGroupEntity>>{};
    for (final item in items) {
      String groupingKey;
      if (item.princepsCisCode != null &&
          cisToPrincipleMap.containsKey(item.princepsCisCode!.toString())) {
        groupingKey = cisToPrincipleMap[item.princepsCisCode!.toString()]!;
      } else if (item.commonPrincipes.isNotEmpty) {
        groupingKey = normalizeCommonPrincipes(item.commonPrincipes);
      } else {
        groupingKey = 'UNIQUE_${item.groupId}';
      }

      if (groupingKey.length <= 2 ||
          suspiciousPrincipes.contains(groupingKey)) {
        groupingKey = 'UNIQUE_${item.groupId}';
      }

      groupedByPrincipes.putIfAbsent(groupingKey, () => []).add(item);
    }

    // ===== PHASE 2: CONSTRUCTION =====
    final result = <Object>[];
    for (final entry in groupedByPrincipes.entries) {
      if (entry.value.length > 1) {
        final firstItem = entry.value.first;
        final clusterPrincipes = firstItem.commonPrincipes.isNotEmpty
            ? firstItem.commonPrincipes
            : Strings.notDetermined;

        final displayName =
            clusterPrincipes.isNotEmpty &&
                clusterPrincipes != Strings.notDetermined
            ? formatPrinciples(clusterPrincipes)
            : Strings.notDetermined;

        final sortKey = _calculateDominantPrinceps(entry.value);

        result.add(
          GroupCluster(
            groups: entry.value,
            commonPrincipes: clusterPrincipes,
            displayName: displayName,
            sortKey: sortKey,
          ),
        );
      } else {
        result.add(entry.value.first);
      }
    }

    // ===== PHASE 3: SORTING =====
    result.sort((a, b) {
      String keyA;
      if (a is GroupCluster) {
        keyA = a.sortKey;
      } else {
        final entity = a as GenericGroupEntity;
        keyA = entity.princepsReferenceName.isNotEmpty
            ? entity.princepsReferenceName
            : Strings.notDetermined;
      }

      String keyB;
      if (b is GroupCluster) {
        keyB = b.sortKey;
      } else {
        final entity = b as GenericGroupEntity;
        keyB = entity.princepsReferenceName.isNotEmpty
            ? entity.princepsReferenceName
            : Strings.notDetermined;
      }

      final normalizedA = normalizePrincipleOptimal(keyA);
      final normalizedB = normalizePrincipleOptimal(keyB);
      return normalizedA.compareTo(normalizedB);
    });

    return result;
  }
}
