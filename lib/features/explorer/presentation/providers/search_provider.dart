import 'dart:async';

import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/logic/explorer_grouping_helper.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_provider.g.dart';

@riverpod
class SearchFiltersNotifier extends _$SearchFiltersNotifier {
  @override
  SearchFilters build() => const SearchFilters(
    voieAdministration: 'orale',
  );

  SearchFilters get filters => state;

  set filters(SearchFilters filters) => state = filters;

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
  final normalizedQuery = NormalizedQuery.fromString(query);

  final catalogDao = ref.watch(catalogDaoProvider);
  return catalogDao.watchMedicaments(normalizedQuery).map((summaries) {
    if (summaries.isEmpty) return const <SearchResultItem>[];
    return _mapSummariesToItems(summaries);
  });
}

List<SearchResultItem> _mapSummariesToItems(
  List<MedicamentSummaryData> summaries,
) {
  final entities = summaries.map(MedicamentEntity.fromData).toList();

  final groupEntities = <String, GenericGroupEntity>{};
  final standaloneItems = <SearchResultItem>[];
  final seenStandaloneNames = <String>{};

  for (final entity in entities) {
    if (entity.groupId == null) {
      final canonicalName = entity.nomCanonique.toUpperCase().trim();
      if (seenStandaloneNames.contains(canonicalName)) continue;
      seenStandaloneNames.add(canonicalName);

      final commonPrinciples = entity.principesActifsCommuns
          .map(normalizePrincipleOptimal)
          .where((p) => p.isNotEmpty)
          .join(', ');

      standaloneItems.add(
        StandaloneResult(
          cisCode: entity.cisCode,
          summary: entity,
          representativeCip:
              entity.representativeCip ??
              Cip13.validated(entity.cisCode.toString()),
          commonPrinciples: commonPrinciples.isNotEmpty
              ? commonPrinciples
              : Strings.notDetermined,
        ),
      );
      continue;
    }

    if (!groupEntities.containsKey(entity.groupId)) {
      final princepsRef =
          entity.princepsDeReference.isNotEmpty &&
              entity.princepsDeReference != 'Inconnu'
          ? entity.princepsDeReference
          : entity.nomCanonique;

      if (entity.groupId != null) {
        final isMemantine =
            entity.princepsDeReference.contains('MEMANTINE') ||
            entity.princepsDeReference.contains('MÉMANTINE') ||
            entity.principesActifsCommuns.any(
              (p) =>
                  p.toUpperCase().contains('MEMANTINE') ||
                  p.toUpperCase().contains('MÉMANTINE'),
            );

        if (isMemantine) {
          LoggerService.debug(
            '[SearchProvider] Mémantine group ${entity.groupId}: '
            'princepsDeReference=${entity.princepsDeReference}, '
            'principesActifsCommuns=${entity.principesActifsCommuns}, '
            'commonPrinciples=${entity.principesActifsCommuns.map(normalizePrincipleOptimal).where((p) => p.isNotEmpty).join(", ")}',
          );
        }
      }

      final commonPrinciples = entity.principesActifsCommuns
          .map(normalizePrincipleOptimal)
          .where((p) => p.isNotEmpty)
          .join(', ');

      final princepsCisCode = entity.isPrinceps ? entity.cisCode : null;

      groupEntities[entity.groupId!.toString()] = GenericGroupEntity(
        groupId: entity.groupId!,
        commonPrincipes: commonPrinciples.isNotEmpty
            ? commonPrinciples
            : Strings.notDetermined,
        princepsReferenceName: princepsRef,
        princepsCisCode: princepsCisCode,
      );
    } else {
      final existingEntity = groupEntities[entity.groupId!.toString()]!;
      if (existingEntity.princepsCisCode == null && entity.isPrinceps) {
        groupEntities[entity.groupId!.toString()] = GenericGroupEntity(
          groupId: existingEntity.groupId,
          commonPrincipes: existingEntity.commonPrincipes,
          princepsReferenceName: existingEntity.princepsReferenceName,
          princepsCisCode: entity.cisCode,
        );
      }
    }
  }

  final groupedObjects = ExplorerGroupingHelper.groupByCommonPrincipes(
    groupEntities.values.toList(),
  );

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
