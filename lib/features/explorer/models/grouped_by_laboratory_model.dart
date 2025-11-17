// lib/features/explorer/models/grouped_by_laboratory_model.dart
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';

class GroupedByLaboratory {
  const GroupedByLaboratory({required this.laboratory, required this.products});

  final String laboratory;
  final List<Medicament> products;
}
