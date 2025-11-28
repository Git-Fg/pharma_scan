// lib/features/explorer/models/search_filters_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pharma_scan/features/explorer/models/explorer_enums.dart';

part 'search_filters_model.freezed.dart';

@freezed
abstract class SearchFilters with _$SearchFilters {
  const factory SearchFilters({
    String? voieAdministration, // null = toutes, sinon une voie spécifique
    AtcLevel1? atcClass, // null = toutes, sinon une classe ATC Level 1
  }) = _SearchFilters;

  const SearchFilters._();

  bool get hasActiveFilters => voieAdministration != null || atcClass != null;

  SearchFilters copyWithCleared() => const SearchFilters();
}
