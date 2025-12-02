
/// Centralized Regex patterns and parsing tokens used across helper utilities.
class ParsingConstants {
  const ParsingConstants._();

  static final RegExp parentheses = RegExp(r'\s*\([^)]*\)');
  static final RegExp equivalentTo = RegExp(
    'équivalant à',
    caseSensitive: false,
  );

  static final List<RegExp> dosageUnits = [
    RegExp(r'\b\d+([.,]\d+)?\s*mg\b', caseSensitive: false),
    RegExp(r'\b\d+([.,]\d+)?\s*g\b', caseSensitive: false),
    RegExp(r'\b\d+([.,]\d+)?\s*ml\b', caseSensitive: false),
    RegExp(r'\b\d+([.,]\d+)?\s*mL\b', caseSensitive: false),
    RegExp(r'\b\d+([.,]\d+)?\s*µg\b', caseSensitive: false),
    RegExp(r'\b\d+([.,]\d+)?\s*mcg\b', caseSensitive: false),
    RegExp(r'\b\d+([.,]\d+)?\s*ui\b', caseSensitive: false),
    RegExp(r'\b\d+([.,]\d+)?\s*UI\b', caseSensitive: false),
    RegExp(r'\b\d+([.,]\d+)?\s*U\.I\.\b', caseSensitive: false),
    RegExp(r'\b\d+([.,]\d+)?\s*M\.U\.I\.\b', caseSensitive: false),
    RegExp(r'\b\d+([.,]\d+)?\s*%', caseSensitive: false),
    RegExp(r'\b\d+([.,]\d+)?\s*meq\b', caseSensitive: false),
    RegExp(r'\b\d+([.,]\d+)?\s*mol\b', caseSensitive: false),
    RegExp(r'\b\d+([.,]\d+)?\s*gbq\b', caseSensitive: false),
    RegExp(r'\b\d+([.,]\d+)?\s*mbq\b', caseSensitive: false),
    RegExp(r'\b\d+([.,]\d+)?\s*CH\b', caseSensitive: false),
    RegExp(r'\b\d+([.,]\d+)?\s*DH\b', caseSensitive: false),
  ];

  static final RegExp unitSlash = RegExp(r'\s*/[A-Z]+', caseSensitive: false);
  static final RegExp trailingSlash = RegExp(r'\s*/\s*', caseSensitive: false);
  static final RegExp whitespace = RegExp(r'\s+');
  static final RegExp standaloneNumber = RegExp(r'\b(\d+([.,]\d+)?)\b');
  static final RegExp spaceLetter = RegExp(
    r'^\s+[a-zA-Z]',
    caseSensitive: false,
  );
  static final RegExp deFollows = RegExp(r'^de\b', caseSensitive: false);

  static const Set<String> formulationKeywords = {
    'comprimé',
    'gélule',
    'solution',
    'injectable',
    'poudre',
    'sirop',
    'suspension',
    'crème',
    'pommade',
    'gel',
    'collyre',
    'inhalation',
  };
}
