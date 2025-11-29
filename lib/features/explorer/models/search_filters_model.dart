// lib/features/explorer/models/search_filters_model.dart
import 'package:dart_mappable/dart_mappable.dart';
import 'package:pharma_scan/features/explorer/models/explorer_enums.dart';

part 'search_filters_model.mapper.dart';

@MappableClass()
class SearchFilters with SearchFiltersMappable {
  const SearchFilters({
    this.voieAdministration, // null = toutes, sinon une voie spécifique
    this.atcClass, // null = toutes, sinon une classe ATC Level 1
  });

  final String? voieAdministration;
  final AtcLevel1? atcClass;

  bool get hasActiveFilters => voieAdministration != null || atcClass != null;

  SearchFilters copyWithCleared() => const SearchFilters();
}
