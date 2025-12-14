import 'package:pharma_scan/core/database/views.drift.dart'
    show ViewGroupDetail;
import 'package:pharma_scan/core/utils/text_utils.dart';

/// Extension type wrapping [ViewGroupDetail] to decouple UI from Drift rows.
/// ViewGroupDetail already has the correct types (bool, int, double?), so we can use them directly.
extension type GroupDetailEntity(ViewGroupDetail _data)
    implements ViewGroupDetail {
  GroupDetailEntity.fromData(ViewGroupDetail data) : this(data);

  bool get isRevoked => status?.toLowerCase().contains('abrog') ?? false;

  bool get isNotMarketed =>
      status?.toLowerCase().contains('non commercialis') ?? false;

  // Convert String/Int fields to bool - handling both string ('1'/'0', 'true'/'false') and int (1/0) representations
  bool get isPrinceps => _convertToBool(_data.isPrinceps);

  bool get isSurveillance => _convertToBool(_data.isSurveillance);

  bool get isHospitalOnly => _convertToBool(_data.isHospitalOnly);

  bool get isDental => _convertToBool(_data.isDental);

  bool get isList1 => _convertToBool(_data.isList1);

  bool get isList2 => _convertToBool(_data.isList2);

  bool get isNarcotic => _convertToBool(_data.isNarcotic);

  bool get isException => _convertToBool(_data.isException);

  bool get isRestricted => _convertToBool(_data.isRestricted);

  bool get isOtc => _convertToBool(_data.isOtc);

  // Convert String field to int with default fallback
  int get memberType => int.tryParse(_data.memberType?.toString() ?? '0') ?? 0;

  // Convert String field to double?
  double? get prixPublic => _data.prixPublic != null ? double.tryParse(_data.prixPublic!.toString()) : null;

  // Getters pour les propriétés nullable avec valeurs par défaut
  String get codeCip => _data.codeCip ?? '';

  String get parsedTitulaire {
    final summary = _data.summaryTitulaire;
    final official = _data.officialTitulaire;
    final titulaire = summary ?? official;
    if (titulaire == null || titulaire.isEmpty) return '';
    return parseMainTitulaire(titulaire);
  }

  // Helper to convert potentially string/int values to boolean
  // Handles various database representations: 1/0, '1'/'0', 'true'/'false', 't'/'f', etc.
  static bool _convertToBool(dynamic value) {
    if (value == null) return false;

    if (value is bool) return value;

    if (value is int) return value != 0;

    if (value is String) {
      final lower = value.toLowerCase().trim();
      if (lower == '1' || lower == 'true' || lower == 't' || lower == 'yes' || lower == 'y') {
        return true;
      } else if (lower == '0' || lower == 'false' || lower == 'f' || lower == 'no' || lower == 'n') {
        return false;
      }
    }

    // If conversion isn't straightforward, treat non-empty as true
    return value.toString().isNotEmpty && value.toString() != '0';
  }

  // SMR & ASMR & Safety data (from medicament_summary)
  String? get smrNiveau => _data.smrNiveau;
  String? get smrDate => _data.smrDate;
  String? get asmrNiveau => _data.asmrNiveau;
  String? get asmrDate => _data.asmrDate;
  String? get urlNotice => _data.urlNotice;
  bool get hasSafetyAlert => _convertToBool(_data.hasSafetyAlert);
}
