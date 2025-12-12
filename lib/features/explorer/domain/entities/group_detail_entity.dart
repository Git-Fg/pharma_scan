import 'package:pharma_scan/core/database/views.drift.dart'
    show ViewGroupDetail;
import 'package:pharma_scan/core/logic/sanitizer.dart';

/// Extension type wrapping [ViewGroupDetail] to decouple UI from Drift rows.
/// ViewGroupDetail already has the correct types (bool, int, double?), so we can use them directly.
extension type GroupDetailEntity(ViewGroupDetail _data)
    implements ViewGroupDetail {
  GroupDetailEntity.fromData(ViewGroupDetail data) : this(data);

  bool get isRevoked => status?.toLowerCase().contains('abrog') ?? false;

  bool get isNotMarketed =>
      status?.toLowerCase().contains('non commercialis') ?? false;

  // ViewGroupDetail already has correct types, so we can use them directly
  bool get isPrinceps => _data.isPrinceps;

  bool get isSurveillance => _data.isSurveillance;

  bool get isHospitalOnly => _data.isHospitalOnly;

  bool get isDental => _data.isDental;

  bool get isList1 => _data.isList1;

  bool get isList2 => _data.isList2;

  bool get isNarcotic => _data.isNarcotic;

  bool get isException => _data.isException;

  bool get isRestricted => _data.isRestricted;

  bool get isOtc => _data.isOtc;

  int get memberType => _data.memberType;

  double? get prixPublic => _data.prixPublic;

  // Getters pour les propriétés nullable avec valeurs par défaut
  String get codeCip => _data.codeCip;

  String get parsedTitulaire {
    final summary = _data.summaryTitulaire;
    final official = _data.officialTitulaire;
    final titulaire = summary ?? official;
    if (titulaire == null || titulaire.isEmpty) return '';
    return parseMainTitulaire(titulaire);
  }

  // SMR & ASMR & Safety data (from medicament_summary)
  String? get smrNiveau => _data.smrNiveau;
  String? get smrDate => _data.smrDate;
  String? get asmrNiveau => _data.asmrNiveau;
  String? get asmrDate => _data.asmrDate;
  String? get urlNotice => _data.urlNotice;
  bool get hasSafetyAlert => _data.hasSafetyAlert ?? false;
}
