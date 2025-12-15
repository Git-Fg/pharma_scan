/// Utility for CIP (Code Identifiant Produit) operations.
class CipUtils {
  CipUtils._();

  /// Extracts the 7-digit CIP code (CIP7) from a 13-digit CIP code (CIP13).
  ///
  /// The CIP13 is composed of: `34009` (prefix) + `CIP7` + `Check Digit`.
  ///
  /// Returns null if the input is not a valid CIP13 format (must start with 34009).
  /// If the input is already 7 digits, it is returned as is.
  static String? extractCip7(String? cip13) {
    if (cip13 == null) return null;

    // Already CIP7
    if (cip13.length == 7) return cip13;

    // Must be 13 digits and start with 34009
    if (cip13.length != 13 || !cip13.startsWith('34009')) {
      return null;
    }

    // Extract digits at index 5 to 12 (length 7)
    // 34009 [XXXXXXX] C
    // 01234  5678901  2
    return cip13.substring(5, 12);
  }
}
