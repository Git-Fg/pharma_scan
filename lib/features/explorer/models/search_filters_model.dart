// lib/features/explorer/models/search_filters_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_filters_model.freezed.dart';

@freezed
abstract class SearchFilters with _$SearchFilters {
  const factory SearchFilters({
    @Default('orale')
    String? voieAdministration, // null = toutes, sinon une voie spécifique
    String?
    atcClass, // null = toutes, sinon une classe ATC Level 1 (A, B, C, etc.)
  }) = _SearchFilters;

  const SearchFilters._();

  bool get hasActiveFilters => voieAdministration != null || atcClass != null;

  SearchFilters copyWithCleared() => const SearchFilters();
}
