// lib/features/explorer/models/grouped_generic_model.dart
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';

class GroupedGeneric {
  const GroupedGeneric({
    required this.baseName,
    required this.products,
  });

  final String baseName;
  final List<Medicament> products;
}

