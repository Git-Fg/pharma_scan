// test/fixtures/data_factory.dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:pharma_scan/core/database/database.dart';

/// WHY: Centralize creation of integration-test data that matches the
/// Server-Side ETL architecture where data is inserted directly into
/// medicament_summary and related final tables.
@immutable
class MedicamentDefinition {
  const MedicamentDefinition({
    required this.cisCode,
    required this.cipCode,
    required this.nomCanonique,
    required this.princepsDeReference,
    this.isPrinceps = false,
    this.clusterId,
    this.groupId,
    this.principesActifs,
    this.formattedDosage,
    this.formePharmaceutique,
    this.voiesAdministration,
    this.memberType = 0,
    this.procedureType,
    this.labName,
    this.conditionsPrescription,
    this.dateAmm,
    this.isSurveillance = false,
    this.atcCode,
    this.status,
    this.priceMin,
    this.priceMax,
    this.ansmAlertUrl,
    this.isHospital = false,
    this.isDental = false,
    this.isList1 = false,
    this.isList2 = false,
    this.isNarcotic = false,
    this.isException = false,
    this.isRestricted = false,
    this.isOtc = true,
    this.smrNiveau,
    this.smrDate,
    this.asmrNiveau,
    this.asmrDate,
    this.urlNotice,
    this.hasSafetyAlert = false,
  });

  final String cisCode;
  final String cipCode;
  final String nomCanonique;
  final String princepsDeReference;
  final bool isPrinceps;
  final String? clusterId;
  final String? groupId;
  final List<String>? principesActifs;
  final String? formattedDosage;
  final String? formePharmaceutique;
  final String? voiesAdministration;
  final int memberType;
  final String? procedureType;
  final String? labName;
  final String? conditionsPrescription;
  final String? dateAmm;
  final bool isSurveillance;
  final String? atcCode;
  final String? status;
  final double? priceMin;
  final double? priceMax;
  final String? ansmAlertUrl;
  final bool isHospital;
  final bool isDental;
  final bool isList1;
  final bool isList2;
  final bool isNarcotic;
  final bool isException;
  final bool isRestricted;
  final bool isOtc;
  final String? smrNiveau;
  final String? smrDate;
  final String? asmrNiveau;
  final String? asmrDate;
  final String? urlNotice;
  final bool hasSafetyAlert;
}

class ClusterDefinition {
  const ClusterDefinition({
    required this.clusterId,
    required this.clusterName,
    this.substanceCode,
    this.clusterPrinceps,
  });

  final String clusterId;
  final String clusterName;
  final String? substanceCode;
  final String? clusterPrinceps;
}

class DataFactory {
  static const String _defaultClusterId = 'CLUSTER_1';

  /// Creates a complete dataset ready for insertion into the database.
  /// Returns medicament summaries, clusters, and laboratories.
  static Future<SeedData> createDataset({
    required List<MedicamentDefinition> medicaments,
    List<ClusterDefinition>? clusters,
  }) async {
    final summaries = <MedicamentSummaryCompanion>[];
    final clusterNames = <ClusterNamesCompanion>[];
    final laboratories = <LaboratoriesCompanion>[];
    final labIds = <String, int>{};
    int labIdCounter = 1;

    // Process clusters first
    final clusterMap = <String, ClusterDefinition>{};
    if (clusters != null) {
      for (final cluster in clusters) {
        clusterMap[cluster.clusterId] = cluster;
        clusterNames.add(
          ClusterNamesCompanion.insert(
            clusterId: cluster.clusterId,
            clusterName: cluster.clusterName,
            substanceCode: cluster.substanceCode,
            clusterPrinceps: cluster.clusterPrinceps,
          ),
        );
      }
    }

    // Process medicaments
    for (final med in medicaments) {
      // Handle laboratory
      final labNameToUse = med.labName ?? 'LAB_${med.cisCode}';
      final labId = labIds.putIfAbsent(labNameToUse, () {
        final newId = labIdCounter++;
        laboratories.add(
          LaboratoriesCompanion.insert(
            id: newId,
            name: labNameToUse,
          ),
        );
        return newId;
      });

      // Convert principes actifs to JSON
      String? principesJson;
      if (med.principesActifs != null && med.principesActifs!.isNotEmpty) {
        principesJson = jsonEncode(med.principesActifs);
      }

      summaries.add(
        MedicamentSummaryCompanion.insert(
          cisCode: med.cisCode,
          nomCanonique: med.nomCanonique,
          princepsDeReference: med.princepsDeReference,
          isPrinceps: med.isPrinceps,
          clusterId: med.clusterId != null ? Value(med.clusterId!) : const Value.absent(),
          groupId: med.groupId != null ? Value(med.groupId!) : const Value.absent(),
          principesActifsCommuns: principesJson != null ? Value(principesJson) : const Value.absent(),
          formattedDosage: med.formattedDosage != null ? Value(med.formattedDosage!) : const Value.absent(),
          formePharmaceutique: med.formePharmaceutique != null ? Value(med.formePharmaceutique!) : const Value.absent(),
          voiesAdministration: med.voiesAdministration != null ? Value(med.voiesAdministration!) : const Value.absent(),
          memberType: med.memberType,
          princepsBrandName: med.isPrinceps ? med.nomCanonique : med.princepsDeReference,
          procedureType: med.procedureType != null ? Value(med.procedureType!) : const Value.absent(),
          titulaireId: labId,
          conditionsPrescription: med.conditionsPrescription != null ? Value(med.conditionsPrescription!) : const Value.absent(),
          dateAmm: med.dateAmm != null ? Value(med.dateAmm!) : const Value.absent(),
          isSurveillance: med.isSurveillance,
          atcCode: med.atcCode != null ? Value(med.atcCode!) : const Value.absent(),
          status: med.status != null ? Value(med.status!) : const Value.absent(),
          priceMin: med.priceMin != null ? Value(med.priceMin!) : const Value.absent(),
          priceMax: med.priceMax != null ? Value(med.priceMax!) : const Value.absent(),
          ansmAlertUrl: med.ansmAlertUrl != null ? Value(med.ansmAlertUrl!) : const Value.absent(),
          isHospital: med.isHospital,
          isDental: med.isDental,
          isList1: med.isList1,
          isList2: med.isList2,
          isNarcotic: med.isNarcotic,
          isException: med.isException,
          isRestricted: med.isRestricted,
          isOtc: med.isOtc,
          smrNiveau: med.smrNiveau != null ? Value(med.smrNiveau!) : const Value.absent(),
          smrDate: med.smrDate != null ? Value(med.smrDate!) : const Value.absent(),
          asmrNiveau: med.asmrNiveau != null ? Value(med.asmrNiveau!) : const Value.absent(),
          asmrDate: med.asmrDate != null ? Value(med.asmrDate!) : const Value.absent(),
          urlNotice: med.urlNotice != null ? Value(med.urlNotice!) : const Value.absent(),
          hasSafetyAlert: med.hasSafetyAlert,
          representativeCip: med.cipCode.isNotEmpty ? Value(med.cipCode) : const Value.absent(),
        ),
      );
    }

    return SeedData(
      medicamentSummaries: summaries,
      clusterNames: clusterNames,
      laboratories: laboratories,
    );
  }

  /// Convenience factory for a basic group with one princeps and one generic.
  static Future<SeedData> createBasicGroup({
    String clusterId = _defaultClusterId,
    String clusterName = 'TEST GROUP',
    String princepsCip = '3400930012345',
    String genericCip = '3400930054321',
    String princepsCis = 'CIS_PRINCEPS',
    String genericCis = 'CIS_GENERIC',
    String princepsName = 'PRINCEPS DRUG',
    String genericName = 'GENERIC DRUG',
    String princepsLab = 'PRINCEPS LAB',
    String genericLab = 'GENERIC LAB',
    List<String> principesActifs = const ['ACTIVE_PRINCIPLE'],
    String dosage = '500 mg',
    String forme = 'Comprimé',
  }) async {
    return createDataset(
      clusters: [
        ClusterDefinition(
          clusterId: clusterId,
          clusterName: clusterName,
          substanceCode: principesActifs.first,
        ),
      ],
      medicaments: [
        MedicamentDefinition(
          cisCode: princepsCis,
          cipCode: princepsCip,
          nomCanonique: princepsName,
          princepsDeReference: princepsName,
          isPrinceps: true,
          clusterId: clusterId,
          principesActifs: principesActifs,
          formattedDosage: dosage,
          formePharmaceutique: forme,
          labName: princepsLab,
        ),
        MedicamentDefinition(
          cisCode: genericCis,
          cipCode: genericCip,
          nomCanonique: genericName,
          princepsDeReference: princepsName,
          isPrinceps: false,
          clusterId: clusterId,
          principesActifs: principesActifs,
          formattedDosage: dosage,
          formePharmaceutique: forme,
          labName: genericLab,
        ),
      ],
    );
  }

  /// Creates a dataset with multiple dosages of the same princeps medication.
  /// Useful for testing dosage-bucketing functionality.
  static Future<SeedData> createMultiDosageGroup({
    required List<({String cip, String cis, String name, String dosage})> princepsDefinitions,
    String clusterId = _defaultClusterId,
    String clusterName = 'MULTI_DOSAGE_GROUP',
    String labName = 'TEST LABORATORY',
    List<String> principesActifs = const ['ACTIVE_PRINCIPLE'],
    String forme = 'Comprimé',
  }) async {
    final medicaments = princepsDefinitions.map(
      (def) => MedicamentDefinition(
        cisCode: def.cis,
        cipCode: def.cip,
        nomCanonique: def.name,
        princepsDeReference: def.name,
        isPrinceps: true,
        clusterId: clusterId,
        principesActifs: principesActifs,
        formattedDosage: def.dosage,
        formePharmaceutique: forme,
        labName: labName,
      ),
    ).toList();

    return createDataset(
      clusters: [
        ClusterDefinition(
          clusterId: clusterId,
          clusterName: clusterName,
          substanceCode: principesActifs.first,
        ),
      ],
      medicaments: medicaments,
    );
  }

  /// Creates a comprehensive test dataset with various medication types.
  static Future<SeedData> createComprehensiveDataset() async {
    return createDataset(
      clusters: [
        ClusterDefinition(
          clusterId: 'PARACETAMOL',
          clusterName: 'Paracétamol',
          substanceCode: 'Paracétamol',
        ),
        ClusterDefinition(
          clusterId: 'IBUPROFEN',
          clusterName: 'Ibuprofène',
          substanceCode: 'Ibuprofène',
        ),
      ],
      medicaments: [
        // Paracetamol group
        MedicamentDefinition(
          cisCode: 'CIS_DOLIPRANE',
          cipCode: '3400930012345',
          nomCanonique: 'Doliprane 500mg',
          princepsDeReference: 'Doliprane',
          isPrinceps: true,
          clusterId: 'PARACETAMOL',
          principesActifs: ['Paracétamol'],
          formattedDosage: '500 mg',
          formePharmaceutique: 'Comprimé',
          labName: 'SANOFI',
          isOtc: true,
        ),
        MedicamentDefinition(
          cisCode: 'CIS_PARA_BIO',
          cipCode: '3400930054321',
          nomCanonique: 'Paracétamol Biogaran 500mg',
          princepsDeReference: 'Doliprane',
          isPrinceps: false,
          clusterId: 'PARACETAMOL',
          principesActifs: ['Paracétamol'],
          formattedDosage: '500 mg',
          formePharmaceutique: 'Comprimé',
          labName: 'BIOGARAN',
          isOtc: true,
        ),
        // Ibuprofen group
        MedicamentDefinition(
          cisCode: 'CIS_ADVIL',
          cipCode: '3400930098765',
          nomCanonique: 'Advil 200mg',
          princepsDeReference: 'Advil',
          isPrinceps: true,
          clusterId: 'IBUPROFEN',
          principesActifs: ['Ibuprofène'],
          formattedDosage: '200 mg',
          formePharmaceutique: 'Gélule',
          labName: 'PFIZER',
          isOtc: true,
        ),
        MedicamentDefinition(
          cisCode: 'CIS_NUROFEN',
          cipCode: '3400930067890',
          nomCanonique: 'Nurofen 400mg',
          princepsDeReference: 'Advil',
          isPrinceps: false,
          clusterId: 'IBUPROFEN',
          principesActifs: ['Ibuprofène'],
          formattedDosage: '400 mg',
          formePharmaceutique: 'Comprimé',
          labName: 'RECKITT BENCKISER',
          isOtc: false,
        ),
      ],
    );
  }
}