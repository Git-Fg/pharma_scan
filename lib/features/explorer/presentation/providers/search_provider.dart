import 'dart:async';

import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/mixins/safe_async_notifier_mixin.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_provider.g.dart';

@riverpod
class SearchFiltersNotifier extends _$SearchFiltersNotifier with SafeAsyncNotifierMixin {
  @override
  SearchFilters build() => const SearchFilters(
        voieAdministration: 'orale',
      );

  SearchFilters get filters => state;

  set filters(SearchFilters filters) {
    if (isMounted(context: 'SearchFiltersNotifier.setFilters')) {
      state = filters;
    }
  }

  void clearFilters() {
    if (isMounted(context: 'SearchFiltersNotifier.clearFilters')) {
      state = const SearchFilters();
    }
  }
}

@riverpod
Stream<List<SearchResultItem>> searchResults(Ref ref, String rawQuery) {
  final query = rawQuery.trim();
  if (query.isEmpty) {
    return Stream<List<SearchResultItem>>.value(const <SearchResultItem>[]);
  }
  final normalizedQuery = NormalizedQuery.fromString(query);

  return Stream.fromFuture(
    ref
        .read(catalogDaoProvider)
        .searchMedicaments(
          normalizedQuery,
        )
        .then((medicaments) => medicaments
            .map((med) => med.toSearchResultItem())
            .whereType<SearchResultItem>()
            .toList()),
  );
}

extension MedicamentEntityToSearchResult on MedicamentEntity {
  SearchResultItem? toSearchResultItem() {
    final repCip = representativeCip;
    if (repCip == null) return null;

    return StandaloneResult(
      cisCode: cisCode,
      summary: this,
      representativeCip: repCip,
      commonPrinciples: data.principesActifsCommuns ?? '',
    );
  }
}
