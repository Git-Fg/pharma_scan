// lib/features/explorer/models/explorer_enums.dart

import 'package:pharma_scan/core/utils/strings.dart';

enum AtcLevel1 {
  a,
  b,
  c,
  d,
  g,
  h,
  j,
  l,
  m,
  n,
  p,
  r,
  s,
  v;

  /// Returns the uppercase ATC Level 1 code (e.g., 'A', 'B', 'C')
  String get code => name.toUpperCase();

  /// Returns the localized label for this ATC Level 1 class
  /// Delegates to Strings.getAtcLevel1Label to maintain single source of truth
  String get label => Strings.getAtcLevel1Label(code) ?? code;
}

enum FormCategory {
  oral, // Comprimé, gélule, capsule, lyophilisat
  syrup, // Sirop, suspension buvable
  drinkableDrops, // Solution buvable, gouttes buvables
  sachet,
  injectable,
  externalUse,
  ophthalmic,
  nasalOrl,
  gynecological,
  other, // Formes non classées
  homeopathy, // Homéopathie
  phytotherapy, // Phytothérapie
}
