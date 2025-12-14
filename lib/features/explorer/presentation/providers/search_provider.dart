import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';
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
