import 'package:pharma_scan/core/database/models/medicament_summary_data.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';

/// Extension Type wrapping [MedicamentSummaryData] to decouple UI from database schema.
///
/// This provides a zero-cost abstraction (no runtime overhead) that:
/// - Hides database implementation details from the UI layer
/// - Enables future migration to different data sources (SDUI, remote APIs)
/// - Prevents tight coupling: renaming a DB column only requires updating this type
///
/// **2025 Standard:** All database rows must be wrapped in Extension Types before
/// reaching the UI layer. See `.cursor/rules/domain-modeling.mdc` for details.
extension type MedicamentEntity(
  (MedicamentSummaryData data, String? labName) _value
) {
  // ============================================================================
  // Factory Constructors
  // ============================================================================

  /// Creates a [MedicamentEntity] from a [MedicamentSummaryData] instance.
  MedicamentEntity.fromData(
    MedicamentSummaryData data, {
    String? labName,
  }) : this((data, labName));

  /// Read-only access to the underlying Drift data.
  MedicamentSummaryData get data => _value.$1;

  // ============================================================================
  // Core Identity Properties
  // ============================================================================

  /// CIS code (unique identifier for the medication)
  ///
  /// Returns a validated [CisCode] if the code has the correct length (8 characters).
  /// In production, CIS codes should always be 8 characters, but this handles edge cases
  /// gracefully (e.g., test data with shorter codes).
  CisCode get cisCode {
    final code = data.cisCode;
    if (code.length == 8) {
      return CisCode.validated(code);
    }
    return CisCode.unsafe(code);
  }

  /// Group ID (nullable for standalone medications)
  GroupId? get groupId =>
      data.groupId != null ? GroupId.validated(data.groupId!) : null;

  /// Holder (titulaire) of the medication
  String? get titulaire => _value.$2;

  /// Representative CIP code (for standalone medications)
  Cip13? get representativeCip => data.representativeCip != null
      ? Cip13.validated(data.representativeCip!)
      : null;

  /// True when the medication has been revoked/abrogated.
  bool get isRevoked => data.status?.toLowerCase().contains('abrog') ?? false;

  /// True when the medication is not marketed.
  bool get isNotMarketed =>
      data.status?.toLowerCase().contains('non commercialis') ?? false;
}
