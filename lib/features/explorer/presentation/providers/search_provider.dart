import 'dart:async';

import 'package:pharma_scan/core/domain/types/semantic_types.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
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

  /// Explicit method for updating filters (preferred over setter for clarity)
  void setFilters(SearchFilters filters) {
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
  final normalizedQuery = NormalizedQuery.fromString(query);

  return Stream.fromFuture(
    ref
        .read(catalogDaoProvider)
        .searchMedicaments(
          normalizedQuery,
        )
        .then((medicaments) => medicaments
            .map((med) => _medicamentToSearchResult(med))
            .whereType<SearchResultItem>()
            .toList()),
  );
}

SearchResultItem? _medicamentToSearchResult(MedicamentEntity medicament) {
  final repCip = medicament.representativeCip;
  if (repCip == null) return null;

  return StandaloneResult(
    cisCode: medicament.cisCode,
    summary: medicament,
    representativeCip: repCip,
    commonPrinciples: medicament.dbData.principesActifsCommuns ?? '',
  );
}
