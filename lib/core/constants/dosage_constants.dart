// lib/core/constants/dosage_constants.dart

// WHY: Constants for dosage units and known numbered molecules.
// Used by sanitizer functions for cleaning active principle names.
class DosageConstants {
  DosageConstants._();

  // WHY: List of dosage units for reference and potential future use
  static const List<String> units = [
    'mg',
    'g',
    'ml',
    'mL',
    'µg',
    'mcg',
    'ui',
    'UI',
    'U.I.',
    'M.U.I.',
    '%',
    'meq',
    'mmol',
    'gbq',
    'mbq',
    'CH', // Homéopathie (centésimale hahnemannienne)
    'DH', // Homéopathie (décimale hahnemannienne)
  ];

  // WHY: Known molecules with numbers in their names that must be preserved during sanitization.
  // These are special cases where the number is part of the molecule name (e.g., "A 313", "4000 UI").
  // This list is shared between parser and sanitizer to prevent logic drift.
  static const Set<String> knownNumberedMolecules = {
    '4000',
    '3350',
    '980',
    '940',
    '6000',
    '2,4',
    '2.4',
  };
}
