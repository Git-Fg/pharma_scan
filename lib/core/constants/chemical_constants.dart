
/// Centralized chemical constants for salt prefixes, suffixes, and mineral tokens.
class ChemicalConstants {
  ChemicalConstants._();

  /// Salt prefixes that appear at the beginning of molecule names.
  /// Example: "CHLORHYDRATE DE METFORMINE" -> "METFORMINE"
  static const List<String> saltPrefixes = [
    'FUMARATE ACIDE DE',
    'HEMIFUMARATE DE',
    'CHLORHYDRATE DIHYDRATE DE',
    'MALÉATE DE',
    'MALEATE DE',
    "MALATE D'",
    'MALATE DE',
    "CHLORHYDRATE D'",
    'CHLORHYDRATE DE',
    'TOSILATE DE',
    'TOSYLATE DE',
  ];

  /// Salt suffixes that appear at the end of molecule names.
  /// These are removed during normalization to extract the base molecule.
  static const List<String> saltSuffixes = [
    // From sanitizer.dart
    'MAGNESIQUE DIHYDRATE',
    'MONOSODIQUE ANHYDRE',
    'BASE',
    'DISODIQUE',
    'DE SODIUM',
    'DE POTASSIUM',
    'DE CALCIUM',
    'DE MAGNESIUM',
    'ARGININE',
    'TERT-BUTYLAMINE',
    'TERT BUTYLAMINE',
    'ERBUMINE',
    'OLAMINE',
    'MAGNESIQUE TRIHYDRATE',
    // Hydrate and solvate markers (valsartan complexes, hydrates, etc.)
    'HEMIPENTAHYDRATE',
    'HEMIPENTAHYDRAT',
    'MONOHYDRATE',
    'DIHYDRATE',
    'TRIHYDRATE',
    'PENTAHYDRATE',
    'SESQUIHYDRATE',
    // Accented hydrate variants (appear in raw BDPM labels)
    'HÉMIPENTAHYDRATÉ',
    'MONOHYDRATÉ',
    'DIHYDRATÉ',
    'TRIHYDRATÉ',
    'PENTAHYDRATÉ',
    'SESQUIHYDRATÉ',
    // From bdpm_file_parser.dart (additional salts)
    'TOSILATE',
    'TERTBUTYLAMINE',
    'MALEATE',
    'MALÉATE',
    'CHLORHYDRATE',
    'SULFATE',
    'TARTRATE',
    'BESILATE',
    'BÉSILATE',
    'MESILATE',
    'MÉSILATE',
    'SUCCINATE',
    'FUMARATE',
    'OXALATE',
    'CITRATE',
    'ACETATE',
    'ACÉTATE',
    'LACTATE',
    'VALERATE',
    'VALÉRATE',
    'PROPIONATE',
    'BUTYRATE',
    'PHOSPHATE',
    'NITRATE',
    'BROMHYDRATE',
  ];

  /// Mineral tokens used for detecting pure inorganic compounds.
  /// These are preserved when they constitute the entire molecule name.
  static const Set<String> mineralTokens = {
    'MAGNESIUM',
    'MAGNESIQUE',
    'SODIUM',
    'POTASSIUM',
    'CALCIUM',
    'MONOSODIQUE',
    'DISODIQUE',
    'ZINC',
  };
}
