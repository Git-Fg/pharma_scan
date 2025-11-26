// lib/features/explorer/models/grouped_by_product_model.dart
import 'package:collection/collection.dart';
import 'package:decimal/decimal.dart';
import 'package:pharma_scan/core/database/database.dart' as drift_db;
import 'package:pharma_scan/core/database/daos/library_dao.dart';
import 'package:pharma_scan/core/utils/dosage_utils.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';

// WHY: Simple data class for medication items in grouped products
// Contains only the fields needed by the UI, extracted from GroupMemberData
class MedicationItem {
  const MedicationItem({
    required this.nom,
    required this.codeCip,
    required this.titulaire,
    required this.formePharmaceutique,
    this.dosage,
    this.dosageUnit,
    this.groupId,
  });

  final String nom;
  final String codeCip;
  final String titulaire;
  final String formePharmaceutique;
  final Decimal? dosage;
  final String? dosageUnit;
  final String? groupId;

  String? get formattedDosage {
    final value = dosage;
    final unit = dosageUnit?.trim() ?? '';
    final hasUnit = unit.isNotEmpty;

    if (value == null && !hasUnit) return null;
    if (value == null) return unit;

    final formattedValue = formatDecimal(value);
    return hasUnit ? '$formattedValue $unit' : formattedValue;
  }
}

class GroupedByProduct {
  const GroupedByProduct({
    required this.productName,
    this.dosage,
    this.dosageUnit,
    required this.laboratories,
    required this.medicaments,
  });

  final String productName;
  final Decimal? dosage;
  final String? dosageUnit;
  final List<String> laboratories;
  final List<MedicationItem> medicaments;
}

// WHY: Extension to convert GroupMemberData to MedicationItem
extension GroupMemberDataToItem on GroupMemberData {
  MedicationItem toMedicationItem(
    Map<String, List<drift_db.PrincipesActif>> principesByCip,
  ) {
    final principesData =
        principesByCip[medicamentRow.codeCip] ??
        const <drift_db.PrincipesActif>[];
    final firstPrincipe = principesData.isNotEmpty ? principesData.first : null;

    // WHY: Apply conditional naming logic based on medication type
    // Princeps use CIS.Denomination (nomSpecialite) cleaned via subtraction
    // Generics use Group Label (nomCanonique) split at " - "
    String name;
    if (groupMemberRow.type == 0) {
      // Princeps: Use CIS.Denomination (nomSpecialite) cleaned via subtraction
      name = cleanStandaloneName(
        rawName: specialiteRow.nomSpecialite,
        officialForm: specialiteRow.formePharmaceutique,
        officialLab: specialiteRow.titulaire,
      );
    } else if (groupMemberRow.type == 1) {
      // Generic: Split Group Label at " - " and take first part
      name = summaryRow.nomCanonique.split(' - ').first.trim();
    } else {
      // Fallback for unknown types
      name = summaryRow.nomCanonique;
    }

    // WHY: Remove dosage information from the name since dosage is displayed separately
    name = deriveGroupTitleFromName(name);

    return MedicationItem(
      nom: name,
      codeCip: medicamentRow.codeCip,
      titulaire: parseMainTitulaire(specialiteRow.titulaire),
      formePharmaceutique: specialiteRow.formePharmaceutique ?? '',
      dosage: parseDecimalValue(firstPrincipe?.dosage),
      dosageUnit: firstPrincipe?.dosageUnit ?? '',
      groupId: summaryRow.groupId,
    );
  }
}

// WHY: Helper function to group medication items by product name and dosage
// Moved from mappers.dart to work with MedicationItem instead of Medicament
// WHY: This function only handles grouping/bucketing logic. All name cleaning
// and parsing is done in toMedicationItem extension, ensuring MedicationItem.nom
// is already clean when it reaches this function.
List<GroupedByProduct> groupMedicationsByProduct(
  List<MedicationItem> medications, {
  required String groupCanonicalName,
  required Decimal? groupPrimaryDosage,
}) {
  if (medications.isEmpty) return [];

  final buckets = <String, _ProductGroupBucket>{};

  for (final medication in medications) {
    // WHY: Use medication.nom directly - it's already cleaned by deriveGroupTitleFromName
    // in toMedicationItem extension. Fallback to groupCanonicalName only if name is empty.
    final nameToUse = medication.nom.isNotEmpty
        ? medication.nom
        : groupCanonicalName;

    final dosageToUse = medication.dosage ?? groupPrimaryDosage;
    final unitToUse = medication.dosageUnit ?? '';
    // WHY: Normalize form for grouping key (uppercase, trimmed) - this is formatting
    // for grouping purposes, not parsing/cleaning
    final formToUse = medication.formePharmaceutique.toUpperCase();

    final dosageKey = dosageToUse?.toString() ?? 'null';
    final unitKey = unitToUse.toUpperCase();
    // WHY: Include form in grouping key to ensure Form + Dosage + Molecule grouping
    final key = '${nameToUse.toUpperCase()}|$formToUse|$dosageKey|$unitKey';

    final bucket = buckets.putIfAbsent(
      key,
      () => _ProductGroupBucket(
        productName: nameToUse,
        dosage: dosageToUse,
        dosageUnit: unitToUse,
        formePharmaceutique: medication.formePharmaceutique,
      ),
    );

    // WHY: Add laboratory to bucket if present (already cleaned by parseMainTitulaire)
    if (medication.titulaire.isNotEmpty) {
      bucket.laboratories.add(medication.titulaire);
    }
    bucket.medicaments.add(medication);
  }

  final groupedProducts = buckets.values.map((bucket) {
    final laboratories = bucket.laboratories.toList()..sort();
    final presentations = List<MedicationItem>.from(bucket.medicaments)
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

class _ProductGroupBucket {
  _ProductGroupBucket({
    required this.productName,
    required this.dosage,
    required this.dosageUnit,
    required this.formePharmaceutique,
  });

  final String productName;
  final Decimal? dosage;
  final String? dosageUnit;
  final String formePharmaceutique;
  final Set<String> laboratories = <String>{};
  final List<MedicationItem> medicaments = [];
}
