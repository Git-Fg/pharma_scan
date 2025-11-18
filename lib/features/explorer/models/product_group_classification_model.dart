// lib/features/explorer/models/product_group_classification_model.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pharma_scan/features/explorer/models/grouped_by_product_model.dart';

part 'product_group_classification_model.freezed.dart';

@freezed
abstract class ProductGroupClassification with _$ProductGroupClassification {
  const factory ProductGroupClassification({
    required String groupId,
    required String syntheticTitle,
    required List<String> commonActiveIngredients,
    required List<String> distinctDosages,
    required List<String> distinctFormulations,
    required List<GroupedByProduct> princeps,
    required List<GroupedByProduct> generics,
    required List<GroupedByProduct> relatedPrinceps,
  }) = _ProductGroupClassification;
}
