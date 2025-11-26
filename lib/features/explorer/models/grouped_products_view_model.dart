import 'package:decimal/decimal.dart';
import 'package:pharma_scan/core/database/daos/library_dao.dart';
import 'package:pharma_scan/features/explorer/models/grouped_by_product_model.dart';

class GroupedProductsViewModel {
  const GroupedProductsViewModel({
    required this.groupData,
    required this.princeps,
    required this.generics,
    required this.relatedPrinceps,
  });

  final ProductGroupData groupData;
  final List<GroupedByProduct> princeps;
  final List<GroupedByProduct> generics;
  final List<GroupedByProduct> relatedPrinceps;

  int get princepsPresentationCount => _countPresentations(princeps);
  int get genericsPresentationCount => _countPresentations(generics);
  int get relatedPrincepsCount => _countPresentations(relatedPrinceps);

  static int _countPresentations(List<GroupedByProduct> products) {
    return products.fold<int>(
      0,
      (total, group) => total + group.medicaments.length,
    );
  }
}

GroupedProductsViewModel buildGroupedProductsViewModel(
  ProductGroupData groupData,
) {
  final groupCanonicalName = groupData.memberRows.isNotEmpty
      ? groupData.memberRows.first.summaryRow.princepsDeReference
      : (groupData.commonPrincipes.isNotEmpty
            ? groupData.commonPrincipes.join(' + ')
            : '');

  final princepsRows = groupData.memberRows
      .where((m) => m.groupMemberRow.type == 0)
      .toList();

  Decimal? groupPrimaryDosage;
  if (princepsRows.isNotEmpty) {
    final firstPrincepsPrincipes =
        groupData.principesByCip[princepsRows.first.medicamentRow.codeCip] ??
        const [];
    if (firstPrincepsPrincipes.isNotEmpty) {
      final dosageStr = firstPrincepsPrincipes.first.dosage;
      if (dosageStr != null) {
        groupPrimaryDosage = Decimal.tryParse(dosageStr);
      }
    }
  }

  final princepsItems = <MedicationItem>[];
  final genericsItems = <MedicationItem>[];

  for (final memberRow in groupData.memberRows) {
    final item = memberRow.toMedicationItem(groupData.principesByCip);
    if (memberRow.groupMemberRow.type == 0) {
      princepsItems.add(item);
    } else {
      genericsItems.add(item);
    }
  }

  final groupedPrinceps = groupMedicationsByProduct(
    princepsItems,
    groupCanonicalName: groupCanonicalName,
    groupPrimaryDosage: groupPrimaryDosage,
  );
  final groupedGenerics = groupMedicationsByProduct(
    genericsItems,
    groupCanonicalName: groupCanonicalName,
    groupPrimaryDosage: groupPrimaryDosage,
  );

  final relatedItems = groupData.relatedPrincepsRows
      .map((row) => row.toMedicationItem(groupData.principesByCip))
      .toList();
  final groupedRelatedPrinceps = groupMedicationsByProduct(
    relatedItems,
    groupCanonicalName: groupCanonicalName,
    groupPrimaryDosage: groupPrimaryDosage,
  );

  return GroupedProductsViewModel(
    groupData: groupData,
    princeps: groupedPrinceps,
    generics: groupedGenerics,
    relatedPrinceps: groupedRelatedPrinceps,
  );
}
