// lib/features/explorer/models/search_result_item_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_entity.dart';

part 'search_result_item_model.freezed.dart';

@freezed
sealed class SearchResultItem with _$SearchResultItem {
  // WHY: Group-level result - returns GenericGroupEntity without hydrating full medication lists
  // Medications are lazy-loaded when user navigates to group detail view
  const factory SearchResultItem.groupResult({
    required GenericGroupEntity group,
  }) = _GroupResult;

  const factory SearchResultItem.princepsResult({
    required MedicamentSummaryData princeps,
    required List<MedicamentSummaryData> generics,
    required String groupId,
    required String commonPrinciples,
  }) = _PrincepsResult;

  const factory SearchResultItem.genericResult({
    required MedicamentSummaryData generic,
    required List<MedicamentSummaryData> princeps,
    required String groupId,
    required String commonPrinciples,
  }) = _GenericResult;

  const factory SearchResultItem.standaloneResult({
    required String cisCode,
    required MedicamentSummaryData summary,
    required String representativeCip,
    required String commonPrinciples,
  }) = _StandaloneResult;
}
