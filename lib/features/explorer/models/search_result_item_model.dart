// lib/features/explorer/models/search_result_item_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';

part 'search_result_item_model.freezed.dart';

@freezed
sealed class SearchResultItem with _$SearchResultItem {
  const factory SearchResultItem.princepsResult({
    required Medicament princeps,
    required List<Medicament> generics,
    required String groupId,
    required String commonPrinciples,
  }) = _PrincepsResult;

  const factory SearchResultItem.genericResult({
    required Medicament generic,
    required List<Medicament> princeps,
    required String groupId,
    required String commonPrinciples,
  }) = _GenericResult;

  const factory SearchResultItem.standaloneResult({
    required Medicament medicament,
    required String commonPrinciples,
  }) = _StandaloneResult;
}
