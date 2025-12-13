// test/fixtures/seed_builder.dart
// Test fixtures use SQL-first approach for data insertion

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/database/dbschema.drift.dart' as i1;

/// WHY: Fluent builder pattern for creating test database seed data.
/// Simplifies test setup by providing a readable API instead of manually constructing Maps.
/// This version inserts data directly into the final aggregated tables (medicament_summary, cluster_names)
/// to match the Server-Side ETL architecture where the database arrives pre-aggregated.
class SeedBuilder {
  SeedBuilder();

  final List<Map<String, dynamic>> _medicamentSummaries = [];
  final List<Map<String, dynamic>> _clusterNames = [];
  final List<Map<String, dynamic>> _laboratories = [];
  final Map<String, int> _labIds = {};
  String? _currentClusterId;
  int _labIdCounter = 1;

  /// WHY: Context switching method to link subsequent medications to a cluster.
  /// Creates the cluster entry and sets it as the current context.
  /// Subsequent calls to `addMedication` will be associated with this cluster.
  SeedBuilder inCluster(
    String clusterId,
    String clusterName, {
    String? substanceCode,
  }) {
    // Check if cluster already exists
    var existingCluster = false;
    for (final c in _clusterNames) {
      final cClusterId = c['clusterId'] as String?;
      if (cClusterId != null && cClusterId == clusterId) {
        existingCluster = true;
        break;
      }
    }

    if (!existingCluster) {
      _clusterNames.add({
        'clusterId': clusterId,
        'clusterName': clusterName,
        'substanceCode': substanceCode,
      });
    }

    _currentClusterId = clusterId;
    // WHY: Fluent builder pattern requires returning this for method chaining
    // ignore: avoid_returning_this
    return this;
  }

  /// Alias for inCluster - sets group context for subsequent medications.
  /// This is a convenience method that works the same as inCluster.
  SeedBuilder inGroup(String groupId, String groupName) {
    return inCluster(groupId, groupName);
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
    List<String>? principesActifsList,
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
    final labNameToUse = labName ?? 'LAB_$cisCode';
    final labId = _labIds.putIfAbsent(labNameToUse, () {
      final newId = _labIdCounter++;
      _laboratories.add({
        'id': newId,
        'name': labNameToUse,
      });
      return newId;
    });

    // Convert JSON arrays to strings if needed
    String? principesJson;
    if (principesActifsList != null) {
      principesJson = jsonEncode(principesActifsList);
    } else if (principesActifsCommuns != null) {
      if (principesActifsCommuns.startsWith('[')) {
        principesJson = principesActifsCommuns;
      } else {
        principesJson = jsonEncode([principesActifsCommuns]);
      }
    }

    _medicamentSummaries.add({
      'cisCode': cisCode,
      'nomCanonique': nomCanonique,
      'princepsDeReference': princepsDeReference,
      'isPrinceps': isPrinceps,
      'clusterId': finalClusterId,
      'groupId': groupId,
      'principesActifsCommuns': principesJson,
      'formattedDosage': formattedDosage,
      'formePharmaceutique': formePharmaceutique,
      'voiesAdministration': voiesAdministration,
      'memberType': memberType,
      'princepsBrandName': isPrinceps ? nomCanonique : princepsDeReference,
      'procedureType': procedureType,
      'titulaireId': labId,
      'conditionsPrescription': conditionsPrescription,
      'dateAmm': dateAmm,
      'isSurveillance': isSurveillance,
      'atcCode': atcCode,
      'status': status,
      'priceMin': priceMin,
      'priceMax': priceMax,
      'aggregatedConditions': '[]',
      'ansmAlertUrl': ansmAlertUrl,
      'isHospital': isHospital,
      'isDental': isDental,
      'isList1': isList1,
      'isList2': isList2,
      'isNarcotic': isNarcotic,
      'isException': isException,
      'isRestricted': isRestricted,
      'isOtc': isOtc,
      'smrNiveau': smrNiveau,
      'smrDate': smrDate,
      'asmrNiveau': asmrNiveau,
      'asmrDate': asmrDate,
      'urlNotice': urlNotice,
      'hasSafetyAlert': hasSafetyAlert,
      'representativeCip': cipCode,
    });

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
    String? atcCode,
    String? conditionsPrescription,
    bool isOtc = true,
    bool isNarcotic = false,
    bool isRestricted = false,
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
      atcCode: atcCode,
      conditionsPrescription: conditionsPrescription,
      isOtc: isOtc,
      isNarcotic: isNarcotic,
      isRestricted: isRestricted,
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
    bool isOtc = true,
    bool isRestricted = false,
  }) {
    // Use provided cluster ID or generate from princeps name
    final finalClusterId = clusterId ??
        (princepsName != null ? _generateClusterId(princepsName) : null);

    return addMedication(
      cisCode: cisCode,
      cipCode: cipCode,
      nomCanonique: name,
      princepsDeReference: princepsName ?? 'UNKNOWN_PRINCEPS',
      clusterId: finalClusterId,
      groupId: groupId,
      formattedDosage: dosage,
      formePharmaceutique: form,
      labName: lab,
      isOtc: isOtc,
      isRestricted: isRestricted,
    );
  }

  /// WHY: Generates a unique cluster ID from medication name.
  String _generateClusterId(String name) {
    return name
        .toUpperCase()
        .replaceAll(RegExp('[^A-Z0-9]'), '_')
        .replaceAll(RegExp('_+'), '_')
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
      // Insert laboratories using Drift Companions
      if (data.laboratories.isNotEmpty) {
        for (final lab in data.laboratories) {
          await database.into(database.laboratories).insertOnConflictUpdate(
                i1.LaboratoriesCompanion(
                  id: Value(lab['id'] as int),
                  name: Value(lab['name'] as String),
                ),
              );
        }
      }

      // Insert clusters using Drift Companions
      if (data.clusterNames.isNotEmpty) {
        for (final cluster in data.clusterNames) {
          await database.into(database.clusterNames).insertOnConflictUpdate(
                i1.ClusterNamesCompanion(
                  clusterId: Value(cluster['clusterId'] as String),
                  clusterName: Value(cluster['clusterName'] as String),
                  substanceCode:
                      Value(cluster['substanceCode'] as String? ?? ''),
                ),
              );
        }
      }

      // Insert medicament summaries using Drift Companions
      if (data.medicamentSummaries.isNotEmpty) {
        for (final summary in data.medicamentSummaries) {
          await database
              .into(database.medicamentSummary)
              .insertOnConflictUpdate(
                i1.MedicamentSummaryCompanion(
                  cisCode: Value(summary['cisCode'] as String),
                  nomCanonique: Value(summary['nomCanonique'] as String),
                  princepsDeReference:
                      Value(summary['princepsDeReference'] as String),
                  isPrinceps: Value(summary['isPrinceps'] as bool),
                  clusterId: Value(summary['clusterId'] as String? ?? ''),
                  groupId: Value(summary['groupId'] as String? ?? ''),
                  memberType: Value(summary['memberType'] as int),
                  principesActifsCommuns: Value(
                    summary['principesActifsCommuns'] as String? ?? '[]',
                  ),
                  formattedDosage:
                      Value(summary['formattedDosage'] as String? ?? ''),
                  formePharmaceutique:
                      Value(summary['formePharmaceutique'] as String? ?? ''),
                  voiesAdministration:
                      Value(summary['voiesAdministration'] as String? ?? ''),
                  princepsBrandName:
                      Value(summary['princepsBrandName'] as String),
                  procedureType:
                      Value(summary['procedureType'] as String? ?? ''),
                  titulaireId: Value(summary['titulaireId'] as int? ?? 0),
                  conditionsPrescription:
                      Value(summary['conditionsPrescription'] as String? ?? ''),
                  dateAmm: Value(summary['dateAmm'] as String? ?? ''),
                  isSurveillance:
                      Value(summary['isSurveillance'] as bool? ?? false),
                  atcCode: Value(summary['atcCode'] as String? ?? ''),
                  status: Value(summary['status'] as String? ?? ''),
                  priceMin: Value(summary['priceMin'] as double? ?? 0.0),
                  priceMax: Value(summary['priceMax'] as double? ?? 0.0),
                  aggregatedConditions:
                      Value(summary['aggregatedConditions'] as String? ?? '[]'),
                  ansmAlertUrl: Value(summary['ansmAlertUrl'] as String? ?? ''),
                  isHospital: Value(summary['isHospital'] as bool? ?? false),
                  isDental: Value(summary['isDental'] as bool? ?? false),
                  isList1: Value(summary['isList1'] as bool? ?? false),
                  isList2: Value(summary['isList2'] as bool? ?? false),
                  isNarcotic: Value(summary['isNarcotic'] as bool? ?? false),
                  isException: Value(summary['isException'] as bool? ?? false),
                  isRestricted:
                      Value(summary['isRestricted'] as bool? ?? false),
                  isOtc: Value(summary['isOtc'] as bool? ?? true),
                  smrNiveau: Value(summary['smrNiveau'] as String? ?? ''),
                  smrDate: Value(summary['smrDate'] as String? ?? ''),
                  asmrNiveau: Value(summary['asmrNiveau'] as String? ?? ''),
                  asmrDate: Value(summary['asmrDate'] as String? ?? ''),
                  urlNotice: Value(summary['urlNotice'] as String? ?? ''),
                  hasSafetyAlert:
                      Value(summary['hasSafetyAlert'] as bool? ?? false),
                  representativeCip:
                      Value(summary['representativeCip'] as String? ?? ''),
                ),
              );
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

  final List<Map<String, dynamic>> medicamentSummaries;
  final List<Map<String, dynamic>> clusterNames;
  final List<Map<String, dynamic>> laboratories;
}
