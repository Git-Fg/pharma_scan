import 'package:collection/collection.dart';
import 'package:decimal/decimal.dart';
import 'package:pharma_scan/core/database/database.dart' as drift_db;
import 'package:pharma_scan/core/utils/dosage_utils.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/models/cluster_summary_model.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/models/grouped_by_product_model.dart';
import 'package:pharma_scan/features/explorer/models/product_group_classification_model.dart';
import 'package:pharma_scan/features/explorer/models/search_candidate_model.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';

extension MedicamentMapper on drift_db.Specialite {
  Medicament toDomain({
    required drift_db.Medicament medicamentDrift,
    required List<drift_db.PrincipesActif> principes,
  }) {
    final firstPrincipe = principes.isNotEmpty ? principes.first : null;

    return Medicament(
      nom: nomSpecialite,
      codeCip: medicamentDrift.codeCip,
      principesActifs: principes.map((p) => p.principe).toList(),
      titulaire: parseMainTitulaire(titulaire),
      formePharmaceutique: formePharmaceutique ?? '',
      dosage: parseDecimalValue(firstPrincipe?.dosage),
      dosageUnit: firstPrincipe?.dosageUnit ?? '',
      conditionsPrescription: conditionsPrescription ?? '',
    );
  }
}

extension MedicamentSummaryMapper on drift_db.MedicamentSummaryData {
  Medicament toDomain({required String codeCip}) {
    return Medicament(
      nom: nomCanonique,
      codeCip: codeCip,
      principesActifs: principesActifsCommuns,
      titulaire: parseMainTitulaire(titulaire),
      formePharmaceutique: formePharmaceutique ?? '',
      conditionsPrescription: conditionsPrescription ?? '',
      groupId: groupId ?? '',
    );
  }

  GenericGroupEntity toGenericGroupEntity() {
    return GenericGroupEntity(
      groupId: groupId ?? '',
      commonPrincipes: principesActifsCommuns.join(' + '),
      princepsReferenceName: princepsDeReference,
    );
  }
}

extension DetailedScanResultMapper on drift_db.DetailedScanResult {
  Medicament toDetailedMedicament({
    required drift_db.MedicamentSummaryData summaryRow,
    required List<drift_db.PrincipesActif> principesRows,
  }) {
    final firstPrincipe = principesRows.isNotEmpty ? principesRows.first : null;
    final commonPrincipes = summaryRow.principesActifsCommuns;
    final rawPrincipes = principesRows.map((p) => p.principe).toList();

    return Medicament(
      nom: nomSpecialite,
      codeCip: codeCip,
      principesActifs: commonPrincipes.isNotEmpty
          ? commonPrincipes
          : rawPrincipes,
      titulaire: parseMainTitulaire(specialiteTitulaire),
      formePharmaceutique: formePharmaceutique ?? '',
      dosage: parseDecimalValue(firstPrincipe?.dosage),
      dosageUnit: firstPrincipe?.dosageUnit ?? '',
      groupId: summaryRow.groupId ?? '',
      groupMemberType: summaryRow.isPrinceps ? 0 : 1,
      conditionsPrescription: specialiteConditionsPrescription ?? '',
    );
  }
}

class GroupMemberData {
  const GroupMemberData({
    required this.medicamentRow,
    required this.specialiteRow,
    required this.groupMemberRow,
    required this.summaryRow,
  });

  final drift_db.Medicament medicamentRow;
  final drift_db.Specialite specialiteRow;
  final drift_db.GroupMember groupMemberRow;
  final drift_db.MedicamentSummaryData summaryRow;
}

class ProductGroupData {
  const ProductGroupData({
    required this.groupId,
    required this.memberRows,
    required this.principesByCip,
    required this.commonPrincipes,
    this.relatedPrincepsRows = const [],
  });

  final String groupId;
  final List<GroupMemberData> memberRows;
  final Map<String, List<drift_db.PrincipesActif>> principesByCip;
  final List<String> commonPrincipes;
  final List<GroupMemberData> relatedPrincepsRows;
}

// Extension for MedicamentSummaryData to SearchCandidate
extension MedicamentSummaryToSearchCandidate on drift_db.MedicamentSummaryData {
  SearchCandidate toSearchCandidate({required String representativeCip}) {
    final medicament = Medicament(
      nom: nomCanonique,
      codeCip: representativeCip,
      principesActifs: principesActifsCommuns,
      titulaire: parseMainTitulaire(titulaire),
      formePharmaceutique: formePharmaceutique ?? '',
      conditionsPrescription: conditionsPrescription ?? '',
    );

    return SearchCandidate(
      cisCode: cisCode,
      nomCanonique: nomCanonique,
      isPrinceps: isPrinceps,
      groupId: groupId,
      commonPrinciples: principesActifsCommuns,
      princepsDeReference: princepsDeReference,
      formePharmaceutique: formePharmaceutique,
      procedureType: procedureType,
      medicament: medicament,
    );
  }
}

// Extension for customSelect cluster summary results
extension ClusterSummaryRowMapper on Map<String, dynamic> {
  ClusterSummary toClusterSummary() {
    // NOTE: principesPayload comes from customSelect as raw string
    final principles = decodePrincipesFromJson(
      this['principes_payload'] as String?,
    );

    return ClusterSummary(
      clusterKey: this['cluster_key'] as String,
      princepsBrandName: this['princeps_brand_name'] as String,
      activeIngredients: principles,
      groupCount: this['group_count'] as int,
      memberCount: this['member_count'] as int,
    );
  }
}

extension ProductGroupDataMapper on ProductGroupData {
  ProductGroupClassification toDomain() {
    final princeps = <Medicament>[];
    final generics = <Medicament>[];
    final formsSet = <String>{};
    final dosageLabels = <String>{};

    for (final memberRow in memberRows) {
      final principesData =
          principesByCip[memberRow.medicamentRow.codeCip] ??
          const <drift_db.PrincipesActif>[];
      final firstPrincipe = principesData.isNotEmpty
          ? principesData.first
          : null;

      final medicament = Medicament(
        nom: memberRow.summaryRow.nomCanonique,
        codeCip: memberRow.medicamentRow.codeCip,
        principesActifs: principesData.map((p) => p.principe).toList(),
        titulaire: parseMainTitulaire(memberRow.specialiteRow.titulaire),
        formePharmaceutique: memberRow.specialiteRow.formePharmaceutique ?? '',
        dosage: parseDecimalValue(firstPrincipe?.dosage),
        dosageUnit: firstPrincipe?.dosageUnit ?? '',
        conditionsPrescription:
            memberRow.specialiteRow.conditionsPrescription ?? '',
      );

      final dosageLabel = medicament.formattedDosage;
      if (dosageLabel != null) {
        dosageLabels.add(dosageLabel);
      }

      final form = memberRow.specialiteRow.formePharmaceutique?.trim();
      if (form != null && form.isNotEmpty) {
        formsSet.add(form);
      }

      if (memberRow.groupMemberRow.type == 0) {
        princeps.add(medicament);
      } else {
        generics.add(medicament);
      }
    }

    final princepsReference = princeps.isNotEmpty ? princeps.first : null;
    final groupCanonicalName = princepsReference != null
        ? princepsReference.nom
        : (commonPrincipes.isNotEmpty
              ? commonPrincipes.join(' + ')
              : Strings.unknown);
    final groupPrimaryDosage = princepsReference?.dosage;

    final groupedPrinceps = _groupMedicamentsByProduct(
      princeps,
      groupCanonicalName: groupCanonicalName,
      groupPrimaryDosage: groupPrimaryDosage,
    );
    final groupedGenerics = _groupMedicamentsByProduct(
      generics,
      groupCanonicalName: groupCanonicalName,
      groupPrimaryDosage: groupPrimaryDosage,
    );

    // WHY: Map related princeps from the DTO (already found in DriftDatabaseService)
    final relatedPrincepsList = <Medicament>[];
    for (final relatedRow in relatedPrincepsRows) {
      final relatedPrincipesData =
          principesByCip[relatedRow.medicamentRow.codeCip] ??
          const <drift_db.PrincipesActif>[];
      final firstPrincipe = relatedPrincipesData.isNotEmpty
          ? relatedPrincipesData.first
          : null;

      final medicament = Medicament(
        nom: relatedRow.summaryRow.nomCanonique,
        codeCip: relatedRow.medicamentRow.codeCip,
        principesActifs: relatedPrincipesData.map((p) => p.principe).toList(),
        titulaire: parseMainTitulaire(relatedRow.specialiteRow.titulaire),
        formePharmaceutique: relatedRow.specialiteRow.formePharmaceutique ?? '',
        dosage: parseDecimalValue(firstPrincipe?.dosage),
        dosageUnit: firstPrincipe?.dosageUnit ?? '',
        conditionsPrescription:
            relatedRow.specialiteRow.conditionsPrescription ?? '',
      );
      relatedPrincepsList.add(medicament);
    }
    final groupedRelatedPrinceps = _groupMedicamentsByProduct(
      relatedPrincepsList,
      groupCanonicalName: groupCanonicalName,
      groupPrimaryDosage: groupPrimaryDosage,
    );

    final distinctFormulations = formsSet.toList()..sort(compareNatural);

    final syntheticTitle = _buildSyntheticTitle(
      groupId: groupId,
      princepsNames: princeps.map((m) => m.nom).toList(),
      fallbackPrincipes: commonPrincipes,
      dosageLabels: dosageLabels.toList(),
      formulations: distinctFormulations,
    );

    return ProductGroupClassification(
      groupId: groupId,
      syntheticTitle: syntheticTitle,
      commonActiveIngredients: commonPrincipes,
      distinctDosages: dosageLabels.toList(),
      distinctFormulations: distinctFormulations.toList(),
      princeps: groupedPrinceps,
      generics: groupedGenerics,
      relatedPrinceps: groupedRelatedPrinceps,
    );
  }
}

// Helper methods for ProductGroupClassification mapping

List<GroupedByProduct> _groupMedicamentsByProduct(
  List<Medicament> medicaments, {
  required String groupCanonicalName,
  required Decimal? groupPrimaryDosage,
}) {
  if (medicaments.isEmpty) return [];

  final buckets = <String, _ProductGroupBucket>{};

  for (final medicament in medicaments) {
    String nameToUse = medicament.nom.trim();
    if (nameToUse.length < 3) {
      nameToUse = groupCanonicalName;
    }

    final dosageToUse = medicament.dosage ?? groupPrimaryDosage;
    final unitToUse = medicament.dosageUnit;

    final dosageKey = dosageToUse?.toString() ?? 'null';
    final unitKey = unitToUse.toUpperCase();
    final key = '${nameToUse.toUpperCase()}|$dosageKey|$unitKey';

    final bucket = buckets.putIfAbsent(
      key,
      () => _ProductGroupBucket(
        productName: nameToUse,
        dosage: dosageToUse,
        dosageUnit: unitToUse,
      ),
    );

    final lab = medicament.titulaire.trim().isNotEmpty
        ? medicament.titulaire.trim()
        : Strings.unknownLab;
    bucket.laboratories.add(lab);
    bucket.medicaments.add(medicament);
  }

  final groupedProducts = buckets.values.map((bucket) {
    final laboratories = bucket.laboratories.toList()..sort();
    final presentations = List<Medicament>.from(bucket.medicaments)
      ..sort((a, b) => compareNatural(a.nom, b.nom));

    return GroupedByProduct(
      productName: bucket.productName,
      dosage: bucket.dosage,
      dosageUnit: bucket.dosageUnit,
      laboratories: laboratories,
      medicaments: presentations,
    );
  }).toList()..sort((a, b) => compareNatural(a.productName, b.productName));

  return groupedProducts;
}

String _buildSyntheticTitle({
  required String groupId,
  required List<String> princepsNames,
  required List<String> dosageLabels,
  required List<String> formulations,
  required List<String> fallbackPrincipes,
}) {
  final candidateNames = princepsNames
      .where((name) => name.trim().isNotEmpty)
      .toList();
  final canonicalName = findCommonPrincepsName(candidateNames);
  final segments = <String>[];

  if (canonicalName.trim().isNotEmpty) {
    segments.add(canonicalName.trim());
  } else if (fallbackPrincipes.isNotEmpty) {
    segments.add(fallbackPrincipes.join(', '));
  } else {
    segments.add('Groupe $groupId');
  }

  if (dosageLabels.isNotEmpty) {
    segments.add(dosageLabels.join(', '));
  }

  if (formulations.isNotEmpty) {
    segments.add(formulations.join(', '));
  }

  return segments.join(' • ');
}

class _ProductGroupBucket {
  _ProductGroupBucket({
    required this.productName,
    required this.dosage,
    required this.dosageUnit,
  });

  final String productName;
  final Decimal? dosage;
  final String? dosageUnit;
  final Set<String> laboratories = <String>{};
  final List<Medicament> medicaments = [];
}
