import 'dart:async';

import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/models/search_result_item_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_provider.g.dart';

@riverpod
class SearchFiltersNotifier extends _$SearchFiltersNotifier {
  @override
  SearchFilters build() => const SearchFilters();

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

  final searchDao = ref.watch(searchDaoProvider);
  final filters = ref.watch(searchFiltersProvider);
  final db = ref.read(appDatabaseProvider);

  // WHY: Watch FTS5 results reactively so UI updates whenever the underlying tables change.
  final summariesStream = searchDao.watchMedicaments(query, filters: filters);

  return summariesStream.asyncMap((summaries) async {
    if (summaries.isEmpty) return const <SearchResultItem>[];

    final cisCodes = summaries.map((s) => s.cisCode).toSet().toList();
    final medicaments = await (db.select(
      db.medicaments,
    )..where((tbl) => tbl.cisCode.isIn(cisCodes))).get();

    final cisToCipMap = <String, String>{};
    for (final med in medicaments) {
      cisToCipMap.putIfAbsent(med.cisCode, () => med.codeCip);
    }

    return _mapSummariesToItems(summaries, cisToCipMap);
  });
}

List<SearchResultItem> _mapSummariesToItems(
  List<MedicamentSummaryData> summaries,
  Map<String, String> cisToCipMap,
) {
  final processedGroups = <String>{};
  final processedStandaloneNames = <String>{};
  final items = <SearchResultItem>[];

  for (final summary in summaries) {
    final groupId = summary.groupId;
    final representativeCip = cisToCipMap[summary.cisCode] ?? summary.cisCode;

    if (groupId != null && groupId.isNotEmpty) {
      if (processedGroups.contains(groupId)) continue;
      processedGroups.add(groupId);

      final commonPrinciples = summary.principesActifsCommuns
          .map(sanitizeActivePrinciple)
          .join(', ');

      items.add(
        SearchResultItem.groupResult(
          group: GenericGroupEntity(
            groupId: groupId,
            commonPrincipes: commonPrinciples,
            princepsReferenceName: summary.princepsDeReference,
          ),
        ),
      );
      continue;
    }

    final canonicalName = summary.nomCanonique.toUpperCase().trim();
    if (processedStandaloneNames.contains(canonicalName)) continue;
    processedStandaloneNames.add(canonicalName);

    final commonPrinciples = summary.principesActifsCommuns
        .map(sanitizeActivePrinciple)
        .join(', ');

    items.add(
      SearchResultItem.standaloneResult(
        cisCode: summary.cisCode,
        summary: summary,
        representativeCip: representativeCip,
        commonPrinciples: commonPrinciples,
      ),
    );
  }

  return items;
}
