// lib/features/explorer/models/search_filters_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_filters_model.freezed.dart';

@freezed
abstract class SearchFilters with _$SearchFilters {
  const factory SearchFilters({
    @Default(null)
    String?
    procedureType, // null = tous, "Autorisation" = Allopathie, "Enregistrement" = Homéopathie/Phytothérapie
    @Default(null)
    String? formePharmaceutique, // null = toutes, sinon une forme spécifique
  }) = _SearchFilters;

  const SearchFilters._();

  bool get hasActiveFilters =>
      procedureType != null || formePharmaceutique != null;

  SearchFilters copyWithCleared() => const SearchFilters();
}
