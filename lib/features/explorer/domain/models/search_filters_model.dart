import 'package:dart_mappable/dart_mappable.dart';
import 'package:pharma_scan/features/explorer/domain/models/explorer_enums.dart';

part 'search_filters_model.mapper.dart';

@MappableClass()
class SearchFilters with SearchFiltersMappable {
  const SearchFilters({
    this.voieAdministration, // null = toutes, sinon une voie spécifique
    this.atcClass, // null = toutes, sinon une classe ATC Level 1
    this.titulaireId, // null = tous les laboratoires
  });

  final String? voieAdministration;
  final AtcLevel1? atcClass;
  final int? titulaireId;

  bool get hasActiveFilters =>
      voieAdministration != null || atcClass != null || titulaireId != null;

  SearchFilters copyWithCleared() => const SearchFilters();
}
