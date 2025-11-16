// lib/features/explorer/models/generic_princeps_pair_model.dart
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';

class GenericPrincepsPair {
  const GenericPrincepsPair({required this.generic, required this.princeps});

  final Medicament generic;
  final List<Medicament> princeps;
}
