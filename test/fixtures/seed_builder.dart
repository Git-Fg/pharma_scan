// test/fixtures/seed_builder.dart
import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';

/// WHY: Fluent builder pattern for creating test database seed data.
/// Simplifies test setup by providing a readable API instead of manually constructing Maps.
/// This version inserts data directly into the final aggregated tables (medicament_summary, cluster_names)
/// to match the Server-Side ETL architecture where the database arrives pre-aggregated.
class SeedBuilder {
  SeedBuilder();

  final List<MedicamentSummaryCompanion> _medicamentSummaries = [];
  final List<ClusterNamesCompanion> _clusterNames = [];
  final List<LaboratoriesCompanion> _laboratories = [];
  final Map<String, int> _labIds = {};
  String? _currentClusterId;
  int _cisCounter = 1;
  int _labIdCounter = 1;

  /// WHY: Context switching method to link subsequent medications to a cluster.
  /// Creates the cluster entry and sets it as the current context.
  /// Subsequent calls to `addMedication` will be associated with this cluster.
  SeedBuilder inCluster(String clusterId, String clusterName, {String? substanceCode}) {
    // Check if cluster already exists
    final existingCluster = _clusterNames
        .where((c) => c.clusterId.value == clusterId)
        .isNotEmpty;

    if (!existingCluster) {
      _clusterNames.add(
        ClusterNamesCompanion.insert(
          clusterId: clusterId,
          clusterName: clusterName,
          substanceCode: substanceCode,
        ),
      );
    }

    _currentClusterId = clusterId;
    // WHY: Fluent builder pattern requires returning this for method chaining
    // ignore: avoid_returning_this
    return this;
  }

  /// WHY: Adds a medication directly to medicament_summary.
  /// This matches the Server-Side ETL architecture where data is pre-aggregated.
  SeedBuilder addMedication({
    required String cisCode,
    required String nomCanonique,
    required String princepsDeReference,
    String? cipCode,
    bool isPrinceps = false,
    String? clusterId,
    String? groupId,
    String? principesActifsCommuns,
    String? formattedDosage,
    String? formePharmaceutique,
    String? voiesAdministration,
    int memberType = 0,
    String? procedureType,
    String? labName,
    String? conditionsPrescription,
    String? dateAmm,
    bool isSurveillance = false,
    String? atcCode,
    String? status,
    double? priceMin,
    double? priceMax,
    String? ansmAlertUrl,
    bool isHospital = false,
    bool isDental = false,
    bool isList1 = false,
    bool isList2 = false,
    bool isNarcotic = false,
    bool isException = false,
    bool isRestricted = false,
    bool isOtc = true,
    String? smrNiveau,
    String? smrDate,
    String? asmrNiveau,
    String? asmrDate,
    String? urlNotice,
    bool hasSafetyAlert = false,
  }) {
    // Use provided cluster ID or current context
    final finalClusterId = clusterId ?? _currentClusterId;

    // Create or get laboratory
    final labNameToUse = labName ?? 'LAB_${cisCode}';
    final labId = _labIds.putIfAbsent(labNameToUse, () {
      final newId = _labIdCounter++;
      _laboratories.add(
        LaboratoriesCompanion.insert(
          id: newId,
          name: labNameToUse,
        ),
      );
      return newId;
    });

    // Convert JSON arrays to strings if needed
    String? principesJson;
    if (principesActifsCommuns != null) {
      if (principesActifsCommuns.startsWith('[')) {
        principesJson = principesActifsCommuns;
      } else {
        principesJson = jsonEncode([principesActifsCommuns]);
      }
    }

    _medicamentSummaries.add(
      MedicamentSummaryCompanion.insert(
        cisCode: cisCode,
        nomCanonique: nomCanonique,
        princepsDeReference: princepsDeReference,
        isPrinceps: isPrinceps,
        clusterId: finalClusterId != null ? Value(finalClusterId) : const Value.absent(),
        groupId: groupId != null ? Value(groupId) : const Value.absent(),
        principesActifsCommuns: principesJson != null ? Value(principesJson) : const Value.absent(),
        formattedDosage: formattedDosage != null ? Value(formattedDosage) : const Value.absent(),
        formePharmaceutique: formePharmaceutique != null ? Value(formePharmaceutique) : const Value.absent(),
        voiesAdministration: voiesAdministration != null ? Value(voiesAdministration) : const Value.absent(),
        memberType: memberType,
        princepsBrandName: isPrinceps ? nomCanonique : princepsDeReference,
        procedureType: procedureType != null ? Value(procedureType) : const Value.absent(),
        titulaireId: labId,
        conditionsPrescription: conditionsPrescription != null ? Value(conditionsPrescription) : const Value.absent(),
        dateAmm: dateAmm != null ? Value(dateAmm) : const Value.absent(),
        isSurveillance: isSurveillance,
        atcCode: atcCode != null ? Value(atcCode) : const Value.absent(),
        status: status != null ? Value(status) : const Value.absent(),
        priceMin: priceMin != null ? Value(priceMin) : const Value.absent(),
        priceMax: priceMax != null ? Value(priceMax) : const Value.absent(),
        ansmAlertUrl: ansmAlertUrl != null ? Value(ansmAlertUrl) : const Value.absent(),
        isHospital: isHospital,
        isDental: isDental,
        isList1: isList1,
        isList2: isList2,
        isNarcotic: isNarcotic,
        isException: isException,
        isRestricted: isRestricted,
        isOtc: isOtc,
        smrNiveau: smrNiveau != null ? Value(smrNiveau) : const Value.absent(),
        smrDate: smrDate != null ? Value(smrDate) : const Value.absent(),
        asmrNiveau: asmrNiveau != null ? Value(asmrNiveau) : const Value.absent(),
        asmrDate: asmrDate != null ? Value(asmrDate) : const Value.absent(),
        urlNotice: urlNotice != null ? Value(urlNotice) : const Value.absent(),
        hasSafetyAlert: hasSafetyAlert,
        representativeCip: cipCode != null ? Value(cipCode) : const Value.absent(),
      ),
    );

    // WHY: Fluent builder pattern requires returning this for method chaining
    // ignore: avoid_returning_this
    return this;
  }

  /// WHY: Convenience method to add a princeps medication.
  SeedBuilder addPrinceps(
    String name,
    String cisCode, {
    String? cipCode,
    String? dosage,
    String? form,
    String? lab,
    String? substanceCode,
    String? clusterId,
  }) {
    // Generate cluster ID from name if not provided
    final finalClusterId = clusterId ?? _generateClusterId(name);

    // Create cluster if needed
    inCluster(finalClusterId, name, substanceCode: substanceCode);

    return addMedication(
      cisCode: cisCode,
      cipCode: cipCode,
      nomCanonique: name,
      princepsDeReference: name,
      isPrinceps: true,
      clusterId: finalClusterId,
      formattedDosage: dosage,
      formePharmaceutique: form,
      labName: lab,
    );
  }

  /// WHY: Convenience method to add a generic medication.
  SeedBuilder addGeneric(
    String name,
    String cisCode, {
    String? cipCode,
    String? dosage,
    String? form,
    String? lab,
    String? princepsName,
    String? substanceCode,
    String? clusterId,
    String? groupId,
  }) {
    // Use provided cluster ID or generate from princeps name
    final finalClusterId = clusterId ?? (princepsName != null ? _generateClusterId(princepsName) : null);

    return addMedication(
      cisCode: cisCode,
      cipCode: cipCode,
      nomCanonique: name,
      princepsDeReference: princepsName ?? 'UNKNOWN_PRINCEPS',
      isPrinceps: false,
      clusterId: finalClusterId,
      groupId: groupId,
      formattedDosage: dosage,
      formePharmaceutique: form,
      labName: lab,
    );
  }

  /// WHY: Generates a unique cluster ID from medication name.
  String _generateClusterId(String name) {
    return name
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  /// WHY: Builds the final data structure for insertion into the database.
  /// Returns a map with all the required collections.
  SeedData build() {
    return SeedData(
      medicamentSummaries: _medicamentSummaries,
      clusterNames: _clusterNames,
      laboratories: _laboratories,
    );
  }

  /// WHY: Convenience method to directly insert data into the database.
  /// This allows for even more concise test setup.
  ///
  /// Usage:
  /// ```dart
  /// await SeedBuilder()
  ///   .addPrinceps('Doliprane 1000mg', 'CIS_1')
  ///   .addGeneric('Paracetamol Biogaran', 'CIS_2', princepsName: 'Doliprane 1000mg')
  ///   .insertInto(database);
  /// ```
  Future<void> insertInto(AppDatabase database) async {
    final data = build();

    // Insert in the correct order to respect foreign key constraints
    await database.transaction(() async {
      // Insert laboratories first
      if (data.laboratories.isNotEmpty) {
        for (final lab in data.laboratories) {
          await database.into(database.laboratories).insert(lab);
        }
      }

      // Insert clusters
      if (data.clusterNames.isNotEmpty) {
        for (final cluster in data.clusterNames) {
          await database.into(database.clusterNames).insert(cluster);
        }
      }

      // Insert medicament summaries
      if (data.medicamentSummaries.isNotEmpty) {
        for (final summary in data.medicamentSummaries) {
          await database.into(database.medicamentSummary).insert(summary);
        }
      }
    });
  }
}

/// WHY: Data structure returned by SeedBuilder.build().
/// Contains all the collections needed to seed the database.
class SeedData {
  const SeedData({
    required this.medicamentSummaries,
    required this.clusterNames,
    required this.laboratories,
  });

  final List<MedicamentSummaryCompanion> medicamentSummaries;
  final List<ClusterNamesCompanion> clusterNames;
  final List<LaboratoriesCompanion> laboratories;
}