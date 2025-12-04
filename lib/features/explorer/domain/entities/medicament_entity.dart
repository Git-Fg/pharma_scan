import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';

/// Extension Type wrapping [MedicamentSummaryData] to decouple UI from database schema.
///
/// This provides a zero-cost abstraction (no runtime overhead) that:
/// - Hides database implementation details from the UI layer
/// - Enables future migration to different data sources (SDUI, remote APIs)
/// - Prevents tight coupling: renaming a DB column only requires updating this type
///
/// **2025 Standard:** All database rows must be wrapped in Extension Types before
/// reaching the UI layer. See `.cursor/rules/flutter-architecture.mdc` for details.
extension type MedicamentEntity(MedicamentSummaryData _data) {
  // ============================================================================
  // Factory Constructors
  // ============================================================================

  /// Creates a [MedicamentEntity] from a [MedicamentSummaryData] instance.
  MedicamentEntity.fromData(MedicamentSummaryData data) : this(data);

  // ============================================================================
  // Core Identity Properties
  // ============================================================================

  /// CIS code (unique identifier for the medication)
  ///
  /// Returns a validated [CisCode] if the code has the correct length (8 characters).
  /// In production, CIS codes should always be 8 characters, but this handles edge cases
  /// gracefully (e.g., test data with shorter codes).
  CisCode get cisCode {
    final code = _data.cisCode;
    if (code.length == 8) {
      return CisCode.validated(code);
    }
    return CisCode.unsafe(code);
  }

  /// Canonical name (display name for the medication)
  String get nomCanonique => _data.nomCanonique;

  /// Display name (alias for nomCanonique for consistency)
  String get displayName => _data.nomCanonique;

  /// Whether this medication is a princeps (reference medication)
  bool get isPrinceps => _data.isPrinceps;

  /// Group ID (nullable for standalone medications)
  GroupId? get groupId =>
      _data.groupId != null ? GroupId.validated(_data.groupId!) : null;

  // ============================================================================
  // Pharmaceutical Properties
  // ============================================================================

  /// Pharmaceutical form (e.g., "Comprimé", "Gélule")
  String? get formePharmaceutique => _data.formePharmaceutique;

  /// Administration routes (semicolon-separated)
  String? get voiesAdministration => _data.voiesAdministration;

  /// Common active principles (list of active ingredients)
  List<String> get principesActifsCommuns => _data.principesActifsCommuns;

  /// Whether the medication has common principles
  bool get hasCommonPrinciples => _data.principesActifsCommuns.isNotEmpty;

  // ============================================================================
  // Group/Reference Properties
  // ============================================================================

  /// Reference princeps name for the group
  String get princepsDeReference => _data.princepsDeReference;

  /// Princeps brand name
  String get princepsBrandName => _data.princepsBrandName;

  // ============================================================================
  // Regulatory & Administrative Properties
  // ============================================================================

  /// Procedure type (e.g., "Autorisation", "AMM")
  String? get procedureType => _data.procedureType;

  /// Holder (titulaire) of the medication
  String? get titulaire => _data.titulaire;

  /// Prescription conditions
  String? get conditionsPrescription => _data.conditionsPrescription;

  /// Whether the medication requires special surveillance
  bool get isSurveillance => _data.isSurveillance;

  /// ATC code (Anatomical Therapeutic Chemical classification)
  String? get atcCode => _data.atcCode;

  /// Administrative status
  String? get status => _data.status;

  // ============================================================================
  // Dosage & Pricing
  // ============================================================================

  /// Formatted dosage string
  String? get formattedDosage => _data.formattedDosage;

  /// Minimum price in the group
  double? get priceMin => _data.priceMin;

  /// Maximum price in the group
  double? get priceMax => _data.priceMax;

  // ============================================================================
  // Regulatory Flags
  // ============================================================================

  /// Whether the medication is hospital-only
  bool get isHospitalOnly => _data.isHospitalOnly;

  /// Whether the medication is dental-only
  bool get isDental => _data.isDental;

  /// Whether the medication is on List 1 (controlled substances)
  bool get isList1 => _data.isList1;

  /// Whether the medication is on List 2 (controlled substances)
  bool get isList2 => _data.isList2;

  /// Whether the medication is a narcotic
  bool get isNarcotic => _data.isNarcotic;

  /// Whether the medication requires exception prescription
  bool get isException => _data.isException;

  /// Whether the medication has restricted prescription
  bool get isRestricted => _data.isRestricted;

  /// Whether the medication is over-the-counter (OTC)
  bool get isOtc => _data.isOtc;

  // ============================================================================
  // Additional Properties
  // ============================================================================

  /// Aggregated conditions (JSON array)
  String? get aggregatedConditions => _data.aggregatedConditions;

  /// ANSM alert URL
  String? get ansmAlertUrl => _data.ansmAlertUrl;

  /// Representative CIP code (for standalone medications)
  Cip13? get representativeCip => _data.representativeCip != null
      ? Cip13.validated(_data.representativeCip!)
      : null;

  // ============================================================================
  // Computed Properties
  // ============================================================================

  /// Whether this medication is a standalone (not part of a group)
  bool get isStandalone => groupId == null;

  /// Whether this medication is part of a group
  bool get isGrouped => groupId != null;
}
