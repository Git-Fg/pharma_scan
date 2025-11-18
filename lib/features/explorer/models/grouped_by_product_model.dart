// lib/features/explorer/models/grouped_by_product_model.dart
import 'package:decimal/decimal.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';

class GroupedByProduct {
  const GroupedByProduct({
    required this.productName,
    this.dosage,
    this.dosageUnit,
    required this.laboratories,
    required this.medicaments,
  });

  final String productName;
  final Decimal? dosage;
  final String? dosageUnit;
  final List<String> laboratories;
  final List<Medicament> medicaments;
}
