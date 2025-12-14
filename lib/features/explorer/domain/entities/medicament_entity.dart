import 'package:pharma_scan/core/database/reference_schema.drift.dart';
import 'package:pharma_scan/core/domain/types/ids.dart';
import 'package:pharma_scan/core/utils/strings.dart';

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
    (MedicamentSummaryData data, String? labName) _value) {
  // ============================================================================
  // Factory Constructors
  // ============================================================================

  /// Creates a [MedicamentEntity] from a [MedicamentSummaryData] instance.
  MedicamentEntity.fromData(
    MedicamentSummaryData data, {
    String? labName,
  }) : this((data, labName));

  /// Creates a [MedicamentEntity] from a [ProductScanCacheData] instance.
  ///
  /// **Performance Optimization**: This denormalized cache table eliminates
  /// the 4-table JOIN required by the traditional `fromData` constructor.
  /// Scanner lookups now require a single table query with PK access.
  MedicamentEntity.fromProductCache(
    ProductScanCacheData cache,
  ) : this((
          MedicamentSummaryData(
            groupId: cache.groupId,
            cisCode: cache.cisCode,
            nomCanonique: cache.nomCanonique,
            princepsDeReference: cache.princepsDeReference,
            princepsBrandName: cache.princepsBrandName,
            isPrinceps: cache.isPrinceps,
            memberType: 0, // Not in cache
            status: null, // Not in cache
            formePharmaceutique: cache.formePharmaceutique,
            voiesAdministration: cache.voiesAdministration,
            principesActifsCommuns: null, // Not needed for scanner
            formattedDosage: cache.formattedDosage,
            titulaireId: cache.titulaireId,
            procedureType: null, // Not needed for scanner
            conditionsPrescription: cache.conditionsPrescription,
            isSurveillance: cache.isSurveillance,
            atcCode: cache.atcCode,
            dateAmm: null, // Not needed for scanner
            aggregatedConditions: null, // Not needed for scanner
            ansmAlertUrl: null, // Not needed for scanner
            representativeCip: cache.representativeCip,
            isHospital: cache.isHospital,
            isDental: 0, // Not in cache (int)
            isList1: 0, // Not in cache (int)
            isList2: 0, // Not in cache (int)
            isNarcotic: cache.isNarcotic,
            isException: 0, // Not in cache (int)
            isRestricted: 0, // Not in cache (int)
            isOtc: 0, // Not in cache (int)
            clusterId: cache.clusterId,
            parentPrincepsCis: null, // Not in cache (Phase 4)
            formId: null, // Not in cache (Phase 2)
            isFormInferred: 0, // Not in cache (int)
          ),
          cache.labName,
        ));

  /// Read-only access to the underlying Drift data.
  MedicamentSummaryData get dbData => _value.$1;

  // ============================================================================
  // Core Identity Properties
  // ============================================================================

  /// CIS code (unique identifier for the medication)
  ///
  /// Returns a validated [CisCode] if the code has the correct length (8 characters).
  /// In production, CIS codes should always be 8 characters, but this handles edge cases
  /// gracefully (e.g., test data with shorter codes).
  CisCode get cisCode {
    final code = dbData.cisCode;
    if (code.length == 8) {
      return CisCode.validated(code);
    }
    return CisCode.unsafe(code);
  }

  /// Group ID (nullable for standalone medications)
  GroupId? get groupId =>
      dbData.groupId != null ? GroupId.validated(dbData.groupId!) : null;

  /// Holder (titulaire) of the medication
  String? get titulaire => _value.$2;

  /// Representative CIP code (for standalone medications)
  Cip13? get representativeCip => dbData.representativeCip != null
      ? Cip13.validated(dbData.representativeCip!)
      : null;

  /// Parent princeps CIS code (normalized)
  CisCode? get parentPrincepsCis => dbData.parentPrincepsCis != null
      ? CisCode.validated(dbData.parentPrincepsCis!)
      : null;

  /// Normalized form ID
  int? get formId => dbData.formId;

  /// True when the medication has been revoked/abrogated.
  bool get isRevoked => dbData.status?.toLowerCase().contains('abrog') ?? false;

  /// True when the medication is not marketed.
  bool get isNotMarketed =>
      dbData.status?.toLowerCase().contains('non commercialis') ?? false;

  /// True when the medication is not marketed.
  bool get isPrinceps => dbData.isPrinceps == 1;

  /// True when the medication is a narcotic.
  bool get isNarcotic => dbData.isNarcotic == 1;

  /// True when the medication is List 1.
  bool get isList1 => dbData.isList1 == 1;

  /// True when the medication is List 2.
  bool get isList2 => dbData.isList2 == 1;

  /// True when the medication is under surveillance.
  bool get isSurveillance => dbData.isSurveillance == 1;

  /// True when the medication is restricted.
  bool get isRestricted => dbData.isRestricted == 1;

  /// True when the medication is an exception.
  bool get isException => dbData.isException == 1;

  /// True when the medication is OTC.
  bool get isOtc => dbData.isOtc == 1;

  /// True when the medication is hospital-only.
  bool get isHospital => dbData.isHospital == 1;

  /// True when the medication is for dental use.
  bool get isDental => dbData.isDental == 1;

  // ============================================================================
  // Normalized Text Properties (Non-Nullable)
  // ============================================================================

  /// Pharmaceutical form (normalized to non-empty string)
  String get formePharmaceutique => dbData.formePharmaceutique ?? '';

  /// Administration routes (normalized to non-empty string)
  String get voiesAdministration => dbData.voiesAdministration ?? '';

  /// Prescription conditions (normalized to non-empty string)
  String get conditionsPrescription => dbData.conditionsPrescription ?? '';

  /// Formatted dosage (normalized to non-empty string)
  String get formattedDosage => dbData.formattedDosage ?? '';

  /// ATC code (normalized to non-empty string)
  String get atcCode => dbData.atcCode ?? '';

  /// Medicament status (normalized to non-empty string)
  String get status => dbData.status ?? '';

  /// Aggregated conditions (normalized to non-empty string)
  String get aggregatedConditions => dbData.aggregatedConditions ?? '';

  /// ANSM alert URL (normalized to non-empty string)
  String get ansmAlertUrl => dbData.ansmAlertUrl ?? '';

  /// Procedure type (normalized to non-empty string)
  String get procedureType => dbData.procedureType ?? '';

  /// AMM date (normalized to non-empty string)
  String get dateAmm => dbData.dateAmm ?? '';

  // ============================================================================
  // Display Logic Getters (Zero-Cost Abstraction for UI)
  // ============================================================================

  /// Compact subtitle for UI display (form + dosage)
  /// Used in scanner bubbles and result cards for space-efficient display
  String get compactSubtitle {
    final form = formePharmaceutique.trim();
    final dosage = formattedDosage.trim();

    if (form.isNotEmpty && dosage.isNotEmpty) {
      return '$form • $dosage';
    } else if (form.isNotEmpty) {
      return form;
    } else if (dosage.isNotEmpty) {
      return dosage;
    }
    return '';
  }

  /// Hero label for prominent display in cards and lists
  /// Prioritizes brand names over generic names for better UX
  String get heroLabel {
    final isGenericWithPrinceps = (dbData.isPrinceps == 0) &&
        groupId != null &&
        dbData.princepsDeReference.isNotEmpty &&
        dbData.princepsDeReference != 'Inconnu';

    if (isGenericWithPrinceps) {
      return dbData.princepsBrandName.isNotEmpty
          ? dbData.princepsBrandName
          : dbData.princepsDeReference;
    }

    if (dbData.isPrinceps == 1) {
      return dbData.princepsBrandName.isNotEmpty
          ? dbData.princepsBrandName
          : dbData.princepsDeReference;
    }

    if (groupId != null) {
      // For generics, use the first part of canonical name
      final parts = dbData.nomCanonique.split(' - ');
      return parts.isNotEmpty ? parts.first.trim() : dbData.nomCanonique;
    }

    return dbData.nomCanonique;
  }

  /// Status flags for UI badges and indicators
  /// Returns a map of status types to their boolean values
  Map<String, bool> get regulatoryFlags => {
        'narcotic': dbData.isNarcotic == 1,
        'list1': dbData.isList1 == 1,
        'list2': dbData.isList2 == 1,
        'exception': dbData.isException == 1,
        'restricted': dbData.isRestricted == 1,
        'otc': dbData.isOtc == 1,
        'dental': dbData.isDental == 1,
        'hospital': dbData.isHospital == 1,
        'surveillance': dbData.isSurveillance == 1,
        'revoked': isRevoked,
        'notMarketed': isNotMarketed,
        'princeps': dbData.isPrinceps == 1,
      };

  /// Check if medication is a generic with associated princeps information
  bool get isGenericWithPrinceps =>
      (dbData.isPrinceps == 0) &&
      groupId != null &&
      dbData.princepsDeReference.isNotEmpty &&
      dbData.princepsDeReference != 'Inconnu';

  /// Full subtitle lines for detailed display (including CIP line)
  /// Returns a list of subtitle lines ordered by importance
  List<String> get fullSubtitleLines {
    final lines = <String>[];

    // Add canonical name for generics with princeps
    if (isGenericWithPrinceps &&
        dbData.nomCanonique.isNotEmpty &&
        dbData.nomCanonique.trim().isNotEmpty) {
      lines.add(dbData.nomCanonique.trim());
    }

    // Add form and dosage
    final compactSubtitle = this.compactSubtitle;
    if (compactSubtitle.isNotEmpty) {
      lines.add(compactSubtitle);
    }

    return lines;
  }

  /// CIP line display format (titulaire • CIP code)
  String cipLineDisplay(String cipString) {
    final titular = titulaire;
    if (titular != null && titular.isNotEmpty) {
      return '${titular.trim()} • ${Strings.cip} $cipString';
    }
    return '${Strings.cip} $cipString';
  }
}
