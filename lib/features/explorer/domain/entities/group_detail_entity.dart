import 'package:pharma_scan/core/database/utils/view_type_converters.dart';
import 'package:pharma_scan/core/database/views.drift.dart'
    show ViewGroupDetail;
import 'package:pharma_scan/core/logic/sanitizer.dart';

/// Extension type wrapping [ViewGroupDetail] to decouple UI from Drift rows.
extension type GroupDetailEntity(ViewGroupDetail _data)
    implements ViewGroupDetail {
  GroupDetailEntity.fromData(ViewGroupDetail data) : this(data);

  bool get isRevoked => status?.toLowerCase().contains('abrog') ?? false;

  bool get isNotMarketed =>
      status?.toLowerCase().contains('non commercialis') ?? false;

  // Type converters pour les propriétés qui sont String? dans la vue mais bool/int/double dans l'usage
  bool get isPrinceps => ViewTypeConverters.toBool(_data.isPrinceps);

  bool get isSurveillance => ViewTypeConverters.toBool(_data.isSurveillance);

  bool get isHospitalOnly => ViewTypeConverters.toBool(_data.isHospitalOnly);

  bool get isDental => ViewTypeConverters.toBool(_data.isDental);

  bool get isList1 => ViewTypeConverters.toBool(_data.isList1);

  bool get isList2 => ViewTypeConverters.toBool(_data.isList2);

  bool get isNarcotic => ViewTypeConverters.toBool(_data.isNarcotic);

  bool get isException => ViewTypeConverters.toBool(_data.isException);

  bool get isRestricted => ViewTypeConverters.toBool(_data.isRestricted);

  bool get isOtc => ViewTypeConverters.toBool(_data.isOtc);

  int get memberType => ViewTypeConverters.toIntOrDefault(_data.memberType, 0);

  double? get prixPublic => ViewTypeConverters.toDouble(_data.prixPublic);

  // Getters pour les propriétés nullable avec valeurs par défaut
  String get codeCip => _data.codeCip ?? '';

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
  bool get hasSafetyAlert => ViewTypeConverters.toBool(_data.hasSafetyAlert);
}
