class DosageConstants {
  DosageConstants._();

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
