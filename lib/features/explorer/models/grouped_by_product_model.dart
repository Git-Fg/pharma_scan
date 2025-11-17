// lib/features/explorer/models/grouped_by_product_model.dart
class GroupedByProduct {
  const GroupedByProduct({
    required this.productName,
    this.dosage,
    this.dosageUnit,
    required this.laboratories,
    required this.codeCips,
  });

  final String productName;
  final double? dosage;
  final String? dosageUnit;
  final List<String> laboratories;
  final List<String> codeCips;
}
