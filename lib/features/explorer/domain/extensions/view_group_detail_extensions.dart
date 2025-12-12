import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/utils/formatters.dart';
import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';

/// Extension on GroupDetailEntity for presentation logic
extension GroupDetailPresentation on GroupDetailEntity {
  /// Display name for the medication (princeps or generic)
  String get displayName {
    if (isPrinceps && princepsDeReference != null) {
      return extractPrincepsLabel(princepsDeReference!);
    }
    final nom = nomCanonique ?? '';
    final parts = nom.split(' - ');
    return parts.first.trim();
  }

  /// Parsed titulaire (main lab name)
  String get parsedTitulaire {
    return parseMainTitulaire(summaryTitulaire ?? officialTitulaire);
  }

  /// Form label (nullable, trimmed)
  String? get formLabel {
    final form = formePharmaceutique?.trim();
    return (form?.isNotEmpty ?? false) ? form : null;
  }

  /// Dosage label (nullable, trimmed)
  String? get dosageLabel {
    final dosage = formattedDosage?.trim();
    return (dosage?.isNotEmpty ?? false) ? dosage : null;
  }

  /// Availability status (nullable, trimmed)
  String? get trimmedAvailabilityStatus {
    final status = availabilityStatus?.trim();
    return (status?.isNotEmpty ?? false) ? status : null;
  }

  /// Refund rate (nullable, trimmed)
  String? get trimmedRefundRate {
    final rate = tauxRemboursement?.trim();
    return (rate?.isNotEmpty ?? false) ? rate : null;
  }

  /// Conditions prescription (nullable, trimmed)
  String? get trimmedConditions {
    final conditions = conditionsPrescription?.trim();
    return (conditions?.isNotEmpty ?? false) ? conditions : null;
  }
}

/// Extension on `List<GroupDetailEntity>` for aggregation and grouping logic
extension GroupDetailListExtensions on List<GroupDetailEntity> {
  /// Group header metadata extracted from members
  ({
    String title,
    List<String> commonPrincipes,
    List<String> distinctDosages,
    List<String> distinctFormulations,
  })
  toGroupHeaderMetadata() {
    if (isEmpty) {
      return (
        title: '',
        commonPrincipes: <String>[],
        distinctDosages: <String>[],
        distinctFormulations: <String>[],
      );
    }

    final forms = <String>{};
    final dosages = <String>{};

    for (final member in this) {
      final form = member.formePharmaceutique?.trim();
      if (form != null && form.isNotEmpty) {
        forms.add(form);
      }
      final dosage = member.formattedDosage?.trim();
      if (dosage != null && dosage.isNotEmpty) {
        dosages.add(dosage);
      }
    }

    final princepsRef = first.princepsDeReference;
    final nomCanon = first.nomCanonique;
    final title = (princepsRef != null && princepsRef.isNotEmpty)
        ? extractPrincepsLabel(princepsRef)
        : (nomCanon ?? '');

    // Parse principesActifsCommuns from JSON string
    final principesJson = first.principesActifsCommuns;
    final commonPrincipes = <String>[];
    if (principesJson != null && principesJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(principesJson);
        if (decoded is List) {
          commonPrincipes.addAll(decoded.map((e) => e.toString()));
        }
      } on FormatException {
        // Ignore JSON decode errors
      }
    }

    return (
      title: title.isNotEmpty ? title : 'Unknown',
      commonPrincipes: commonPrincipes,
      distinctDosages: dosages.toList()..sort(),
      distinctFormulations: forms.toList()..sort(),
    );
  }

  /// Build price label from price range
  String? buildPriceLabel() {
    final prices = map((item) => item.prixPublic).nonNulls.toList();
    if (prices.isEmpty) return null;
    prices.sort();
    final minPrice = prices.first;
    final maxPrice = prices.last;
    if ((maxPrice - minPrice).abs() < 0.005) {
      return formatEuro(minPrice);
    }
    return '${formatEuro(minPrice)} – ${formatEuro(maxPrice)}';
  }

  /// Build refund label from refund rates
  String? buildRefundLabel() {
    final rates = <String>{
      for (final member in this)
        if (member.trimmedRefundRate != null) member.trimmedRefundRate!,
    };
    if (rates.isEmpty) return null;
    if (rates.length == 1) return rates.first;
    return rates.join(' • ');
  }

  /// Aggregate conditions from all members
  List<String> aggregateConditions() {
    final segments = <String>{};
    for (final member in this) {
      final condition = member.trimmedConditions;
      if (condition == null || condition.isEmpty) continue;
      final splits = condition.split(RegExp(r'[,;\n]'));
      for (final raw in splits) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) continue;
        segments.add(trimmed);
      }
    }
    return segments.toList()..sort();
  }

  /// Partition list into princeps and generics
  ({
    List<GroupDetailEntity> princeps,
    List<GroupDetailEntity> generics,
  })
  partitionByPrinceps() {
    final princeps = <GroupDetailEntity>[];
    final generics = <GroupDetailEntity>[];

    for (final member in this) {
      if (member.isPrinceps) {
        princeps.add(member);
      } else {
        generics.add(member);
      }
    }

    return (princeps: princeps, generics: generics);
  }

  /// Extract princeps CIS code from first princeps member
  String? extractPrincepsCisCode() {
    return where((m) => m.isPrinceps).firstOrNull?.cisCode;
  }

  /// Extract ANSM alert URL from any member (same at group level)
  String? extractAnsmAlertUrl() {
    final url = firstOrNull?.ansmAlertUrl?.trim();
    return (url?.isNotEmpty ?? false) ? url : null;
  }

  /// Sort using smart comparator (shortage first, then hospital-only, then name)
  List<GroupDetailEntity> sortedBySmartComparator() {
    return List<GroupDetailEntity>.from(this)..sort(_smartMedicationComparator);
  }
}

/// Smart comparator for medications (shortage first, then hospital-only, then name)
int _smartMedicationComparator(
  GroupDetailEntity a,
  GroupDetailEntity b,
) {
  final aShortage = a.trimmedAvailabilityStatus != null;
  final bShortage = b.trimmedAvailabilityStatus != null;
  if (aShortage != bShortage) {
    return aShortage ? 1 : -1;
  }
  final aHospital = a.isHospitalOnly;
  final bHospital = b.isHospitalOnly;
  if (aHospital != bHospital) {
    return aHospital ? 1 : -1;
  }
  return a.displayName.compareTo(b.displayName);
}
