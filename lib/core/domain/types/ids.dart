/// Strongly-typed IDs to avoid mixing distinct code types.
library;

/// CIP-13 code (13 digits) for presentations.
extension type Cip13(String _value) implements String {
  /// Asserts length is 13 in debug mode.
  factory Cip13.validated(String value) {
    assert(
      value.length == 13,
      'CIP code must be exactly 13 digits, got ${value.length}',
    );
    // Use the implicit constructor from implements String
    return value as Cip13;
  }
}

/// CIS code (8 digits) for pharmaceutical specialties.
extension type CisCode(String _value) implements String {
  /// Asserts length is 8 in debug mode.
  factory CisCode.validated(String value) {
    assert(
      value.length == 8,
      'CIS code must be exactly 8 digits, got ${value.length}',
    );
    // Use the implicit constructor from implements String
    return value as CisCode;
  }

  /// Unsafe constructor; bypasses validation (tests/edge cases only).
  factory CisCode.unsafe(String value) {
    return value as CisCode;
  }
}

/// Group identifier for generic clusters.
extension type GroupId(String _value) implements String {
  /// Asserts non-empty in debug mode.
  factory GroupId.validated(String value) {
    assert(
      value.isNotEmpty,
      'Group ID cannot be empty',
    );
    // Use the implicit constructor from implements String
    return value as GroupId;
  }
}
