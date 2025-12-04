/// Strongly-typed ID Extension Types to eliminate primitive obsession.
///
/// These Extension Types provide:
/// - **Type Safety:** Prevents mixing different ID types (e.g., CIP vs CIS codes)
/// - **Validation:** Assertions catch invalid IDs at construction time (debug mode)
/// - **Zero Cost:** No runtime overhead—Extension Types are compile-time wrappers
/// - **Self-Documenting:** Method signatures clearly indicate expected ID type
///
/// **2025 Standard:** All ID types must use Extension Types instead of raw `String`.
/// See `.cursor/rules/flutter-architecture.mdc` for details.
library;

/// CIP-13 code (Code Identifiant de Présentation).
///
/// A 13-digit code that uniquely identifies a pharmaceutical presentation.
/// Used for barcode scanning and product identification.
///
/// **Validation:** Must be exactly 13 characters (digits).
extension type Cip13(String _value) implements String {
  /// Factory constructor that validates and creates a [Cip13].
  ///
  /// **Validation:** In debug mode, asserts that the value is exactly 13 characters.
  ///
  /// Throws an assertion error if validation fails (debug mode only).
  factory Cip13.validated(String value) {
    assert(
      value.length == 13,
      'CIP code must be exactly 13 digits, got ${value.length}',
    );
    // Use the implicit constructor from implements String
    return value as Cip13;
  }
}

/// CIS code (Code Identifiant de Spécialité).
///
/// An 8-digit code that uniquely identifies a pharmaceutical specialty.
/// Used for grouping medications with the same active principles.
///
/// **Validation:** Must be exactly 8 characters (digits).
extension type CisCode(String _value) implements String {
  /// Factory constructor that validates and creates a [CisCode].
  ///
  /// **Validation:** In debug mode, asserts that the value is exactly 8 characters.
  ///
  /// Throws an assertion error if validation fails (debug mode only).
  factory CisCode.validated(String value) {
    assert(
      value.length == 8,
      'CIS code must be exactly 8 digits, got ${value.length}',
    );
    // Use the implicit constructor from implements String
    return value as CisCode;
  }

  /// Unsafe constructor that creates a [CisCode] without validation.
  ///
  /// **Warning:** Only use this for test data or edge cases where the code
  /// length may vary. Production code should always use [CisCode.validated].
  factory CisCode.unsafe(String value) {
    return value as CisCode;
  }
}

/// Group ID for generic medication groups.
///
/// Identifies a group of medications sharing the same active principles.
/// Used for clustering generics and their princeps.
///
/// **Validation:** Must be non-empty.
extension type GroupId(String _value) implements String {
  /// Factory constructor that validates and creates a [GroupId].
  ///
  /// **Validation:** In debug mode, asserts that the value is not empty.
  ///
  /// Throws an assertion error if validation fails (debug mode only).
  factory GroupId.validated(String value) {
    assert(
      value.isNotEmpty,
      'Group ID cannot be empty',
    );
    // Use the implicit constructor from implements String
    return value as GroupId;
  }
}
