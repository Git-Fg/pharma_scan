import 'package:pharma_scan/core/database/database.dart';
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

  // ============================================================================
  // Normalized Text Properties (Non-Nullable)
  // ============================================================================

  /// Pharmaceutical form (normalized to non-empty string)
  String get formePharmaceutique => data.formePharmaceutique ?? '';

  /// Administration routes (normalized to non-empty string)
  String get voiesAdministration => data.voiesAdministration ?? '';

  /// Prescription conditions (normalized to non-empty string)
  String get conditionsPrescription => data.conditionsPrescription ?? '';

  /// Formatted dosage (normalized to non-empty string)
  String get formattedDosage => data.formattedDosage ?? '';

  /// ATC code (normalized to non-empty string)
  String get atcCode => data.atcCode ?? '';

  /// Medicament status (normalized to non-empty string)
  String get status => data.status ?? '';

  /// Aggregated conditions (normalized to non-empty string)
  String get aggregatedConditions => data.aggregatedConditions ?? '';

  /// ANSM alert URL (normalized to non-empty string)
  String get ansmAlertUrl => data.ansmAlertUrl ?? '';

  /// Procedure type (normalized to non-empty string)
  String get procedureType => data.procedureType ?? '';

  /// AMM date (normalized to non-empty string)
  String get dateAmm => data.dateAmm ?? '';

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
    final isGenericWithPrinceps =
        !data.isPrinceps &&
        groupId != null &&
        data.princepsDeReference.isNotEmpty &&
        data.princepsDeReference != 'Inconnu';

    if (isGenericWithPrinceps) {
      return data.princepsBrandName.isNotEmpty
          ? data.princepsBrandName
          : data.princepsDeReference;
    }

    if (data.isPrinceps) {
      return data.princepsBrandName.isNotEmpty
          ? data.princepsBrandName
          : data.princepsDeReference;
    }

    if (groupId != null) {
      // For generics, use the first part of canonical name
      final parts = data.nomCanonique.split(' - ');
      return parts.isNotEmpty ? parts.first.trim() : data.nomCanonique;
    }

    return data.nomCanonique;
  }

  /// Status flags for UI badges and indicators
  /// Returns a map of status types to their boolean values
  Map<String, bool> get statusFlags => {
        'narcotic': data.isNarcotic,
        'list1': data.isList1,
        'list2': data.isList2,
        'exception': data.isException,
        'restricted': data.isRestricted,
        'otc': data.isOtc,
        'dental': data.isDental,
        'hospital': data.isHospital,
        'surveillance': data.isSurveillance,
        'revoked': isRevoked,
        'notMarketed': isNotMarketed,
        'princeps': data.isPrinceps,
      };

  /// Check if medication is a generic with associated princeps information
  bool get isGenericWithPrinceps =>
      !data.isPrinceps &&
      groupId != null &&
      data.princepsDeReference.isNotEmpty &&
      data.princepsDeReference != 'Inconnu';

  /// Full subtitle lines for detailed display (including CIP line)
  /// Returns a list of subtitle lines ordered by importance
  List<String> get fullSubtitleLines {
    final lines = <String>[];

    // Add canonical name for generics with princeps
    if (isGenericWithPrinceps &&
        data.nomCanonique.isNotEmpty &&
        data.nomCanonique.trim().isNotEmpty) {
      lines.add(data.nomCanonique.trim());
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
