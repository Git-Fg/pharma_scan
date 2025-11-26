import 'package:pharma_scan/core/database/database.dart' as db;
import 'package:pharma_scan/core/utils/medicament_helpers.dart';

class MedicationItem {
  const MedicationItem({
    required this.codeCip,
    required this.displayName,
    required this.titulaire,
    required this.isPrinceps,
    this.formLabel,
    this.dosageLabel,
    this.price,
    this.refundRate,
    this.conditions,
    this.isSurveillance = false,
    this.availabilityStatus,
    this.isHospitalOnly = false,
    this.isDental = false,
    this.isList1 = false,
    this.isList2 = false,
    this.isNarcotic = false,
    this.isException = false,
    this.isRestricted = false,
    this.isOtc = false,
  });

  final String codeCip;
  final String displayName;
  final String titulaire;
  final bool isPrinceps;
  final String? formLabel;
  final String? dosageLabel;
  final double? price;
  final String? refundRate;
  final String? conditions;
  final bool isSurveillance;
  final String? availabilityStatus;
  final bool isHospitalOnly;
  final bool isDental;
  final bool isList1;
  final bool isList2;
  final bool isNarcotic;
  final bool isException;
  final bool isRestricted;
  final bool isOtc;

  factory MedicationItem.fromGroupDetail(db.ViewGroupDetail row) {
    final titulaire = parseMainTitulaire(
      row.summaryTitulaire ?? row.officialTitulaire,
    );
    final formLabel = row.formePharmaceutique?.trim();
    final dosageLabel = row.formattedDosage?.trim();
    final isPrinceps = row.isPrinceps;
    final displayName = isPrinceps
        ? extractPrincepsLabel(row.princepsDeReference)
        : _extractGenericName(row.nomCanonique);
    final availabilityStatus = row.availabilityStatus?.trim().isEmpty ?? true
        ? null
        : row.availabilityStatus!.trim();

    return MedicationItem(
      codeCip: row.codeCip,
      displayName: displayName,
      titulaire: titulaire,
      isPrinceps: isPrinceps,
      formLabel: formLabel?.isNotEmpty == true ? formLabel : null,
      dosageLabel: dosageLabel?.isNotEmpty == true ? dosageLabel : null,
      price: row.prixPublic,
      refundRate: row.tauxRemboursement?.trim().isEmpty ?? true
          ? null
          : row.tauxRemboursement!.trim(),
      conditions: row.conditionsPrescription?.trim().isEmpty ?? true
          ? null
          : row.conditionsPrescription!.trim(),
      isSurveillance: row.isSurveillance,
      availabilityStatus: availabilityStatus,
      isHospitalOnly: row.isHospitalOnly,
      isDental: row.isDental,
      isList1: row.isList1,
      isList2: row.isList2,
      isNarcotic: row.isNarcotic,
      isException: row.isException,
      isRestricted: row.isRestricted,
      isOtc: row.isOtc,
    );
  }

  static String _extractGenericName(String canonicalName) {
    final parts = canonicalName.split(' - ');
    return parts.first.trim();
  }
}

class GroupHeaderMetadata {
  const GroupHeaderMetadata({
    required this.title,
    required this.commonPrincipes,
    required this.distinctDosages,
    required this.distinctFormulations,
  });

  final String title;
  final List<String> commonPrincipes;
  final List<String> distinctDosages;
  final List<String> distinctFormulations;

  factory GroupHeaderMetadata.fromMembers(List<db.ViewGroupDetail> members) {
    if (members.isEmpty) {
      return const GroupHeaderMetadata(
        title: '',
        commonPrincipes: <String>[],
        distinctDosages: <String>[],
        distinctFormulations: <String>[],
      );
    }

    final forms = <String>{};
    final dosages = <String>{};

    for (final member in members) {
      final form = member.formePharmaceutique?.trim();
      if (form != null && form.isNotEmpty) {
        forms.add(form);
      }
      final dosage = member.formattedDosage?.trim();
      if (dosage != null && dosage.isNotEmpty) {
        dosages.add(dosage);
      }
    }

    final title = members.first.princepsDeReference.isNotEmpty
        ? extractPrincepsLabel(members.first.princepsDeReference)
        : members.first.nomCanonique;

    return GroupHeaderMetadata(
      title: title,
      commonPrincipes: members.first.principesActifsCommuns,
      distinctDosages: (dosages.toList()..sort()),
      distinctFormulations: (forms.toList()..sort()),
    );
  }
}

class GroupedProductsViewModel {
  const GroupedProductsViewModel({
    required this.metadata,
    required this.princeps,
    required this.generics,
    required this.aggregatedConditions,
    this.priceLabel,
    this.refundLabel,
    this.princepsCisCode,
    this.ansmAlertUrl,
  });

  final GroupHeaderMetadata metadata;
  final List<MedicationItem> princeps;
  final List<MedicationItem> generics;
  final List<String> aggregatedConditions;
  final String? priceLabel;
  final String? refundLabel;
  final String? princepsCisCode;
  final String? ansmAlertUrl;

  bool get hasMembers => princeps.isNotEmpty || generics.isNotEmpty;
}

class RelatedPrincepsItem {
  const RelatedPrincepsItem({required this.groupId, required this.medication});

  final String groupId;
  final MedicationItem medication;

  factory RelatedPrincepsItem.fromGroupDetail(db.ViewGroupDetail row) {
    return RelatedPrincepsItem(
      groupId: row.groupId,
      medication: MedicationItem.fromGroupDetail(row),
    );
  }
}

GroupedProductsViewModel buildGroupedProductsViewModel(
  List<db.ViewGroupDetail> members,
) {
  final metadata = GroupHeaderMetadata.fromMembers(members);
  final items = members.map(MedicationItem.fromGroupDetail).toList();
  final princeps = items.where((item) => item.isPrinceps).toList();
  final generics = items.where((item) => !item.isPrinceps).toList();
  final aggregatedConditions = _aggregateConditions(items);
  final priceLabel = _buildPriceLabel(items);
  final refundLabel = _buildRefundLabel(items);

  // Extract princeps CIS code from first princeps member
  final princepsCisCode = members
      .where((m) => m.isPrinceps)
      .firstOrNull
      ?.cisCode;

  // Extract ANSM alert URL from any member (same at group level)
  final ansmAlertUrl =
      members.firstOrNull?.ansmAlertUrl?.trim().isEmpty == false
      ? members.first.ansmAlertUrl
      : null;

  princeps.sort(_smartMedicationComparator);
  generics.sort(_smartMedicationComparator);

  return GroupedProductsViewModel(
    metadata: metadata,
    princeps: princeps,
    generics: generics,
    aggregatedConditions: aggregatedConditions,
    priceLabel: priceLabel,
    refundLabel: refundLabel,
    princepsCisCode: princepsCisCode,
    ansmAlertUrl: ansmAlertUrl,
  );
}

String? _buildPriceLabel(List<MedicationItem> items) {
  final prices = items.map((item) => item.price).nonNulls.toList();
  if (prices.isEmpty) return null;
  prices.sort();
  final minPrice = prices.first;
  final maxPrice = prices.last;
  if ((maxPrice - minPrice).abs() < 0.005) {
    return _formatPrice(minPrice);
  }
  return '${_formatPrice(minPrice)} – ${_formatPrice(maxPrice)}';
}

String _formatPrice(double value) {
  final fixed = value.toStringAsFixed(2);
  final normalized = fixed.replaceAll('.', ',');
  return '$normalized €';
}

String? _buildRefundLabel(List<MedicationItem> items) {
  final rates = <String>{
    for (final refund in items.map((item) => item.refundRate))
      if (refund != null && refund.isNotEmpty) refund,
  };
  if (rates.isEmpty) return null;
  if (rates.length == 1) return rates.first;
  return rates.join(' • ');
}

List<String> _aggregateConditions(List<MedicationItem> items) {
  final segments = <String>{};
  for (final condition in items.map((item) => item.conditions)) {
    if (condition == null || condition.isEmpty) continue;
    final splits = condition.split(RegExp('[,;\\n]'));
    for (final raw in splits) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      segments.add(trimmed);
    }
  }
  return segments.toList()..sort();
}

int _smartMedicationComparator(MedicationItem a, MedicationItem b) {
  final aShortage = a.availabilityStatus?.isNotEmpty == true;
  final bShortage = b.availabilityStatus?.isNotEmpty == true;
  if (aShortage != bShortage) {
    return aShortage ? 1 : -1;
  }
  if (a.isHospitalOnly != b.isHospitalOnly) {
    return a.isHospitalOnly ? 1 : -1;
  }
  return a.displayName.compareTo(b.displayName);
}
