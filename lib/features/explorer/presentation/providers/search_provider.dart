import 'dart:async';

import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/explorer_grouping_helper.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_provider.g.dart';

@riverpod
class SearchFiltersNotifier extends _$SearchFiltersNotifier {
  @override
  SearchFilters build() => const SearchFilters(
    voieAdministration: 'orale',
  );

  /// Updates the search filters state.
  /// Methods are preferred over setters for Notifiers to maintain clarity and documentation.
  // ignore: use_setters_to_change_properties
  void updateFilters(SearchFilters filters) {
    state = filters;
  }

  void clearFilters() {
    state = const SearchFilters();
  }
}

@riverpod
Stream<List<SearchResultItem>> searchResults(Ref ref, String rawQuery) {
  final query = rawQuery.trim();
  if (query.isEmpty) {
    return Stream<List<SearchResultItem>>.value(const <SearchResultItem>[]);
  }

  final catalogDao = ref.watch(catalogDaoProvider);
  return catalogDao.watchMedicaments(query).map((summaries) {
    if (summaries.isEmpty) return const <SearchResultItem>[];
    return _mapSummariesToItems(summaries);
  });
}

/// Maps summaries to search result items using Explorer grouping logic.
/// This aligns search results with the Explorer tab's molecule-based accordion structure.
List<SearchResultItem> _mapSummariesToItems(
  List<MedicamentSummaryData> summaries,
) {
  final groupEntities = <String, GenericGroupEntity>{};
  final standaloneItems = <SearchResultItem>[];
  final seenStandaloneNames = <String>{};

  for (final summary in summaries) {
    // 1. Handle Standalones
    if (summary.groupId == null) {
      final canonicalName = summary.nomCanonique.toUpperCase().trim();
      if (seenStandaloneNames.contains(canonicalName)) continue;
      seenStandaloneNames.add(canonicalName);

      final commonPrinciples = summary.principesActifsCommuns
          .map(normalizePrincipleOptimal)
          .where((p) => p.isNotEmpty)
          .join(', ');

      standaloneItems.add(
        StandaloneResult(
          cisCode: summary.cisCode,
          summary: summary,
          representativeCip: summary.representativeCip ?? summary.cisCode,
          commonPrinciples: commonPrinciples.isNotEmpty
              ? commonPrinciples
              : Strings.notDetermined,
        ),
      );
      continue;
    }

    // 2. Handle Groups (Deduplicate by groupId)
    // Even if FTS matched "Doliprane" (Princeps) and "Paracetamol Bio" (Generic),
    // they belong to the same groupId. We only want the Group entity once.
    if (!groupEntities.containsKey(summary.groupId)) {
      // Determine the best princeps label for the group
      // If the current row is the princeps or carries the label, good.
      // Otherwise, we rely on what's in the summary.
      final princepsRef =
          summary.princepsDeReference.isNotEmpty &&
              summary.princepsDeReference != 'Inconnu'
          ? summary.princepsDeReference
          : summary.nomCanonique;

      // DEBUG: Log principesActifsCommuns to understand why clustering fails
      // Check if this is a Mémantine-related group by checking groupId or common principles
      if (summary.groupId != null) {
        final isMemantine =
            summary.princepsDeReference.contains('MEMANTINE') ||
            summary.princepsDeReference.contains('MÉMANTINE') ||
            summary.principesActifsCommuns.any(
              (p) =>
                  p.toUpperCase().contains('MEMANTINE') ||
                  p.toUpperCase().contains('MÉMANTINE'),
            );

        if (isMemantine) {
          LoggerService.debug(
            '[SearchProvider] Mémantine group ${summary.groupId}: '
            'princepsDeReference=${summary.princepsDeReference}, '
            'principesActifsCommuns=${summary.principesActifsCommuns}, '
            'commonPrinciples=${summary.principesActifsCommuns.map(normalizePrincipleOptimal).where((p) => p.isNotEmpty).join(", ")}',
          );
        }
      }

      final commonPrinciples = summary.principesActifsCommuns
          .map(normalizePrincipleOptimal)
          .where((p) => p.isNotEmpty)
          .join(', ');

      // Extract princeps CIS code if this row is a princeps
      final princepsCisCode = summary.isPrinceps ? summary.cisCode : null;

      groupEntities[summary.groupId!] = GenericGroupEntity(
        groupId: summary.groupId!,
        commonPrincipes: commonPrinciples.isNotEmpty
            ? commonPrinciples
            : Strings.notDetermined,
        princepsReferenceName: princepsRef,
        princepsCisCode: princepsCisCode,
      );
    } else {
      // If we already have this group but the current row is a princeps,
      // update the princepsCisCode if it wasn't set before
      final existingEntity = groupEntities[summary.groupId!]!;
      if (existingEntity.princepsCisCode == null && summary.isPrinceps) {
        groupEntities[summary.groupId!] = GenericGroupEntity(
          groupId: existingEntity.groupId,
          commonPrincipes: existingEntity.commonPrincipes,
          princepsReferenceName: existingEntity.princepsReferenceName,
          princepsCisCode: summary.cisCode,
        );
      }
    }
  }

  // 3. Apply Clustering Logic (The "Explorer" Magic)
  final groupedObjects = ExplorerGroupingHelper.groupByCommonPrincipes(
    groupEntities.values.toList(),
  );

  // 4. Map to Result Items
  final groupResults = groupedObjects.map((obj) {
    if (obj is GroupCluster) {
      return ClusterResult(
        groups: obj.groups,
        displayName: obj.displayName,
        commonPrincipes: obj.commonPrincipes,
        sortKey: obj.sortKey,
      );
    } else if (obj is GenericGroupEntity) {
      return GroupResult(group: obj);
    }
    throw Exception('Unknown type from grouping helper');
  }).toList();

  return [...groupResults, ...standaloneItems];
}
