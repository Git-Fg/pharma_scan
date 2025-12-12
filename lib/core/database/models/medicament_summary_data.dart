import 'dart:convert';

import 'package:drift/drift.dart';

/// Modèle de données pour medicament_summary (compatible avec l'ancienne API).
///
/// Cette classe peut être construite depuis les résultats de customSelect
/// sur la table medicament_summary du schéma SQL distant.
class MedicamentSummaryData {
  MedicamentSummaryData({
    required this.cisCode,
    required this.nomCanonique,
    required this.isPrinceps,
    required this.memberType,
    required this.princepsDeReference,
    required this.princepsBrandName,
    required this.isSurveillance,
    required this.isHospitalOnly,
    required this.isDental,
    required this.isList1,
    required this.isList2,
    required this.isNarcotic,
    required this.isException,
    required this.isRestricted,
    required this.isOtc,
    this.groupId,
    this.principesActifsCommuns = const [],
    this.formePharmaceutique,
    this.voiesAdministration,
    this.procedureType,
    this.titulaireId,
    this.conditionsPrescription,
    this.dateAmm,
    this.formattedDosage,
    this.atcCode,
    this.status,
    this.priceMin,
    this.priceMax,
    this.aggregatedConditions,
    this.ansmAlertUrl,
    this.representativeCip,
  });

  /// Crée une instance depuis une ligne de résultat SQL
  factory MedicamentSummaryData.fromRow(Map<String, dynamic> row) {
    final principesJson = row['principes_actifs_communs'] as String?;
    var principes = <String>[];
    if (principesJson != null && principesJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(principesJson);
        if (decoded is List) {
          principes = decoded.map((e) => e.toString()).toList();
        }
      } on FormatException {
        // Ignore JSON decode errors
      }
    }

    return MedicamentSummaryData(
      cisCode: row['cis_code'] as String,
      nomCanonique: row['nom_canonique'] as String? ?? '',
      isPrinceps: (row['is_princeps'] as int? ?? 0) == 1,
      groupId: row['group_id'] as String?,
      memberType: row['member_type'] as int? ?? 0,
      principesActifsCommuns: principes,
      princepsDeReference: row['princeps_de_reference'] as String? ?? '',
      formePharmaceutique: row['forme_pharmaceutique'] as String?,
      voiesAdministration: row['voies_administration'] as String?,
      princepsBrandName: row['princeps_brand_name'] as String? ?? '',
      procedureType: row['procedure_type'] as String?,
      titulaireId: row['titulaire_id'] as int?,
      conditionsPrescription: row['conditions_prescription'] as String?,
      dateAmm: row['date_amm'] as String?,
      isSurveillance: (row['is_surveillance'] as int? ?? 0) == 1,
      formattedDosage: row['formatted_dosage'] as String?,
      atcCode: row['atc_code'] as String?,
      status: row['status'] as String?,
      priceMin: (row['price_min'] as num?)?.toDouble(),
      priceMax: (row['price_max'] as num?)?.toDouble(),
      aggregatedConditions: row['aggregated_conditions'] as String?,
      ansmAlertUrl: row['ansm_alert_url'] as String?,
      isHospitalOnly: (row['is_hospital'] as int? ?? 0) == 1,
      isDental: (row['is_dental'] as int? ?? 0) == 1,
      isList1: (row['is_list1'] as int? ?? 0) == 1,
      isList2: (row['is_list2'] as int? ?? 0) == 1,
      isNarcotic: (row['is_narcotic'] as int? ?? 0) == 1,
      isException: (row['is_exception'] as int? ?? 0) == 1,
      isRestricted: (row['is_restricted'] as int? ?? 0) == 1,
      isOtc: (row['is_otc'] as int? ?? 0) == 1,
      representativeCip: row['representative_cip'] as String?,
    );
  }

  /// Crée une instance depuis un QueryRow de Drift
  factory MedicamentSummaryData.fromQueryRow(QueryRow row) {
    final principesJson = row.readNullable<String>('principes_actifs_communs');
    var principes = <String>[];
    if (principesJson != null && principesJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(principesJson);
        if (decoded is List) {
          principes = decoded.map((e) => e.toString()).toList();
        }
      } on FormatException {
        // Ignore JSON decode errors
      }
    }

    return MedicamentSummaryData(
      cisCode: row.read<String>('cis_code'),
      nomCanonique: row.readNullable<String>('nom_canonique') ?? '',
      isPrinceps: (row.readNullable<int>('is_princeps') ?? 0) == 1,
      groupId: row.readNullable<String>('group_id'),
      memberType: row.readNullable<int>('member_type') ?? 0,
      principesActifsCommuns: principes,
      princepsDeReference:
          row.readNullable<String>('princeps_de_reference') ?? '',
      formePharmaceutique: row.readNullable<String>('forme_pharmaceutique'),
      voiesAdministration: row.readNullable<String>('voies_administration'),
      princepsBrandName: row.readNullable<String>('princeps_brand_name') ?? '',
      procedureType: row.readNullable<String>('procedure_type'),
      titulaireId: row.readNullable<int>('titulaire_id'),
      conditionsPrescription: row.readNullable<String>(
        'conditions_prescription',
      ),
      dateAmm: row.readNullable<String>('date_amm'),
      isSurveillance: (row.readNullable<int>('is_surveillance') ?? 0) == 1,
      formattedDosage: row.readNullable<String>('formatted_dosage'),
      atcCode: row.readNullable<String>('atc_code'),
      status: row.readNullable<String>('status'),
      priceMin: row.readNullable<num>('price_min')?.toDouble(),
      priceMax: row.readNullable<num>('price_max')?.toDouble(),
      aggregatedConditions: row.readNullable<String>('aggregated_conditions'),
      ansmAlertUrl: row.readNullable<String>('ansm_alert_url'),
      isHospitalOnly: (row.readNullable<int>('is_hospital') ?? 0) == 1,
      isDental: (row.readNullable<int>('is_dental') ?? 0) == 1,
      isList1: (row.readNullable<int>('is_list1') ?? 0) == 1,
      isList2: (row.readNullable<int>('is_list2') ?? 0) == 1,
      isNarcotic: (row.readNullable<int>('is_narcotic') ?? 0) == 1,
      isException: (row.readNullable<int>('is_exception') ?? 0) == 1,
      isRestricted: (row.readNullable<int>('is_restricted') ?? 0) == 1,
      isOtc: (row.readNullable<int>('is_otc') ?? 0) == 1,
      representativeCip: row.readNullable<String>('representative_cip'),
    );
  }

  final String cisCode;
  final String nomCanonique;
  final bool isPrinceps;
  final String? groupId;
  final int memberType;
  final List<String> principesActifsCommuns;
  final String princepsDeReference;
  final String? formePharmaceutique;
  final String? voiesAdministration;
  final String princepsBrandName;
  final String? procedureType;
  final int? titulaireId;
  final String? conditionsPrescription;
  final String? dateAmm;
  final bool isSurveillance;
  final String? formattedDosage;
  final String? atcCode;
  final String? status;
  final double? priceMin;
  final double? priceMax;
  final String? aggregatedConditions;
  final String? ansmAlertUrl;
  final bool isHospitalOnly;
  final bool isDental;
  final bool isList1;
  final bool isList2;
  final bool isNarcotic;
  final bool isException;
  final bool isRestricted;
  final bool isOtc;
  final String? representativeCip;
}
