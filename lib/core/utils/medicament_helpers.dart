// lib/core/utils/medicament_helpers.dart

String findCommonPrincepsName(List<String> names) {
  if (names.isEmpty) return 'N/A';

  if (names.length == 1) return names.first;

  // Split the first name into words to create the initial prefix
  final List<String> prefixWords = names.first.split(' ');

  // Compare with other names to shorten the prefix
  for (int i = 1; i < names.length; i++) {
    final currentWords = names[i].split(' ');
    int commonLength = 0;
    while (commonLength < prefixWords.length &&
        commonLength < currentWords.length &&
        prefixWords[commonLength] == currentWords[commonLength]) {
      commonLength++;
    }

    // Shrink the prefix to the new common length
    if (commonLength < prefixWords.length) {
      prefixWords.removeRange(commonLength, prefixWords.length);
    }
  }

  if (prefixWords.isEmpty) {
    // Fallback to the shortest name if no common prefix is found
    return names.reduce((a, b) => a.length < b.length ? a : b);
  }

  // Join the words and clean up trailing characters like commas or dots
  return prefixWords.join(' ').trim().replaceAll(RegExp(r'[,.]\s*$'), '');
}

// WHY: Clean the official group label to extract just the active principle name(s).
// The libelle field from generique_groups contains the official group name, which often
// includes dosage and formulation details (e.g., "ACICLOVIR 200 mg, comprimé").
// This function extracts the principle name by removing everything after the first dosage number.
String cleanGroupLabel(String label) {
  // Remove everything after the first sequence of digits, which is typically the dosage.
  // This is a simple, non-regex way to clean up the label for display.
  final parts = label.split(' ');
  final stopIndex = parts.indexWhere(
    (part) => double.tryParse(part.replaceAll(',', '.')) != null,
  );

  if (stopIndex != -1) {
    return parts
        .sublist(0, stopIndex)
        .join(' ')
        .replaceAll(RegExp(r'\s*,$'), '');
  }

  // Fallback for labels without a clear dosage number
  return label.split(',').first.trim();
}
