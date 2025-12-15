import 'package:pharma_scan/core/database/reference_schema.drift.dart'
    show UiGroupDetail;
import 'package:pharma_scan/core/utils/text_utils.dart';

/// Extension type wrapping [UiGroupDetails] to decouple UI from Drift rows.
/// Accesses the actual values from the table data.
extension type GroupDetailEntity(UiGroupDetail _data) {
  GroupDetailEntity.fromData(UiGroupDetail data) : this(data);

  bool get isRevoked => _data.status?.toLowerCase().contains('abrog') ?? false;

  bool get isNotMarketed =>
      _data.status?.toLowerCase().contains('non commercialis') ?? false;

  // Convert Int fields to bool - table data stores as int (0/1)
  bool get isPrinceps => _data.isPrinceps != 0;

  bool get isSurveillance => _data.isSurveillance != 0;

  bool get isHospitalOnly => _data.isHospitalOnly != 0;

  bool get isDental => _data.isDental != 0;

  bool get isList1 => _data.isList1 != 0;

  bool get isList2 => _data.isList2 != 0;

  bool get isNarcotic => _data.isNarcotic != 0;

  bool get isException => _data.isException != 0;

  bool get isRestricted => _data.isRestricted != 0;

  bool get isOtc => _data.isOtc != 0;

  // Access member type as int
  int get memberType => _data.memberType ?? 0;

  // Access price as double?
  double? get prixPublic => _data.prixPublic;

  // Getters pour les propriétés (table provides direct access to values)
  String get cipCode => _data.cipCode;
  String get groupId => _data.groupId;
  String get cisCode => _data.cisCode;
  String get nomCanonique => _data.nomCanonique;
  String get princepsDeReference => _data.princepsDeReference;
  String? get status => _data.status;
  String? get formePharmaceutique => _data.formePharmaceutique;
  String? get voiesAdministration => _data.voiesAdministration;
  String? get principesActifsCommuns => _data.principesActifsCommuns;
  String? get formattedDosage => _data.formattedDosage;
  String? get summaryTitulaire => _data.summaryTitulaire;
  String? get officialTitulaire => _data.officialTitulaire;
  String? get nomSpecialite => _data.nomSpecialite;
  String? get procedureType => _data.procedureType;
  String? get conditionsPrescription => _data.conditionsPrescription;
  String? get atcCode => _data.atcCode;
  String? get tauxRemboursement => _data.tauxRemboursement;
  String? get ansmAlertUrl => _data.ansmAlertUrl;
  String? get smrNiveau => _data.smrNiveau;
  String? get smrDate => _data.smrDate;
  String? get asmrNiveau => _data.asmrNiveau;
  String? get asmrDate => _data.asmrDate;
  String? get urlNotice => _data.urlNotice;
  String? get rawLabel => _data.rawLabel;
  String? get parsingMethod => _data.parsingMethod;
  String? get princepsCisReference => _data.princepsCisReference;

  // Missing getters expected by UI
  String get princepsBrandName => _data.princepsBrandName;
  String? get availabilityStatus => _data.availabilityStatus;

  bool get hasSafetyAlert => _data.hasSafetyAlert != 0;

  String get parsedTitulaire {
    final titulaire = summaryTitulaire ?? officialTitulaire;
    if (titulaire == null || titulaire.isEmpty) return '';
    return parseMainTitulaire(titulaire);
  }
}
