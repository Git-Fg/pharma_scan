import 'dart:async';

import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/view_search_result_extensions.dart';
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
  return catalogDao.watchSearchResultsSql(normalizedQuery).map((rows) {
    if (rows.isEmpty) return const <SearchResultItem>[];
    return rows
        .map((row) => row.toSearchResultItem())
        .whereType<SearchResultItem>()
        .toList();
  });
}
