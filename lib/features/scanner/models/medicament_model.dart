// lib/features/scanner/models/medicament_model.dart
class Medicament {
  final String nom;
  final String codeCip;
  final List<String> principesActifs;

  Medicament({
    required this.nom,
    required this.codeCip,
    required this.principesActifs,
  });
}

