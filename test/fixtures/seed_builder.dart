// test/fixtures/seed_builder.dart
// Test fixtures use SQL-first approach for data insertion

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

  final List<Map<String, dynamic>> _medicamentSummaries = [];
  final List<Map<String, dynamic>> _clusterNames = [];
  final List<Map<String, dynamic>> _laboratories = [];
  final Map<String, int> _labIds = {};
  String? _currentClusterId;
  final int _cisCounter = 1;
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
    final finalClusterId =
        clusterId ??
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
      // Insert laboratories first using raw SQL
      if (data.laboratories.isNotEmpty) {
        for (final lab in data.laboratories) {
          await database.customInsert(
            'INSERT OR REPLACE INTO laboratories (id, name) VALUES (?, ?)',
            variables: [
              Variable.withInt(lab['id'] as int),
              Variable.withString(lab['name'] as String),
            ],
            updates: {database.laboratories},
          );
        }
      }

      // Insert clusters using raw SQL
      if (data.clusterNames.isNotEmpty) {
        for (final cluster in data.clusterNames) {
          await database.customInsert(
            'INSERT OR REPLACE INTO cluster_names (cluster_id, cluster_name, substance_code) VALUES (?, ?, ?)',
            variables: [
              Variable.withString(cluster['clusterId'] as String),
              Variable.withString(cluster['clusterName'] as String),
              Variable.withString(cluster['substanceCode'] as String? ?? ''),
            ],
            updates: {database.clusterNames},
          );
        }
      }

      // Insert medicament summaries and related base tables using raw SQL
      if (data.medicamentSummaries.isNotEmpty) {
        for (final summary in data.medicamentSummaries) {
          final cisCode = summary['cisCode'] as String;
          final cipCode = summary['representativeCip'] as String?;
          final titulaireId = summary['titulaireId'] as int? ?? 0;

          // Insert specialite if not already exists
          if (cipCode != null && cipCode.isNotEmpty) {
            // Check if specialite already exists
            final existingSpecialite = await database
                .customSelect(
                  'SELECT 1 FROM specialites WHERE cis_code = ? LIMIT 1',
                  variables: [Variable.withString(cisCode)],
                  readsFrom: {database.specialites},
                )
                .getSingleOrNull();

            if (existingSpecialite == null) {
              await database.customInsert(
                '''
                INSERT INTO specialites (
                  cis_code, nom_specialite, procedure_type, forme_pharmaceutique,
                  voies_administration, titulaire_id, conditions_prescription,
                  is_surveillance, statut_administratif, etat_commercialisation
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''',
                variables: [
                  Variable.withString(cisCode),
                  Variable.withString(summary['nomCanonique'] as String),
                  Variable.withString(
                    summary['procedureType'] as String? ?? 'Autorisation',
                  ),
                  Variable.withString(
                    summary['formePharmaceutique'] as String? ?? '',
                  ),
                  Variable.withString(
                    summary['voiesAdministration'] as String? ?? '',
                  ),
                  Variable.withInt(titulaireId),
                  Variable.withString(
                    summary['conditionsPrescription'] as String? ?? '',
                  ),
                  Variable.withBool(
                    summary['isSurveillance'] as bool? ?? false,
                  ),
                  Variable.withString(summary['status'] as String? ?? ''),
                  Variable.withString('Commercialisée'),
                ],
                updates: {database.specialites},
              );
            }

            // Insert medicament for CIP lookup
            await database.customInsert(
              '''
              INSERT OR REPLACE INTO medicaments (
                code_cip, cis_code, presentation_label, commercialisation_statut,
                taux_remboursement, prix_public
              ) VALUES (?, ?, ?, ?, ?, ?)
              ''',
              variables: [
                Variable.withString(cipCode),
                Variable.withString(cisCode),
                Variable.withString(''),
                Variable.withString('Commercialisée'),
                Variable.withString(''),
                Variable.withReal(summary['priceMin'] as double? ?? 0.0),
              ],
              updates: {database.medicaments},
            );
          }

          await database.customInsert(
            '''
            INSERT INTO medicament_summary (
              cis_code, nom_canonique, princeps_de_reference, is_princeps,
              cluster_id, group_id, member_type, principes_actifs_communs,
              formatted_dosage, forme_pharmaceutique, voies_administration,
              princeps_brand_name, procedure_type, titulaire_id,
              conditions_prescription, date_amm, is_surveillance, atc_code,
              status, price_min, price_max, aggregated_conditions, ansm_alert_url,
              is_hospital, is_dental, is_list1, is_list2, is_narcotic, is_exception,
              is_restricted, is_otc, smr_niveau, smr_date, asmr_niveau,
              asmr_date, url_notice, has_safety_alert, representative_cip
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            variables: [
              Variable.withString(summary['cisCode'] as String),
              Variable.withString(summary['nomCanonique'] as String),
              Variable.withString(summary['princepsDeReference'] as String),
              Variable.withBool(summary['isPrinceps'] as bool),
              Variable.withString(summary['clusterId'] as String? ?? ''),
              Variable.withString(summary['groupId'] as String? ?? ''),
              Variable.withInt(summary['memberType'] as int),
              Variable.withString(
                summary['principesActifsCommuns'] as String? ?? '[]',
              ),
              Variable.withString(summary['formattedDosage'] as String? ?? ''),
              Variable.withString(
                summary['formePharmaceutique'] as String? ?? '',
              ),
              Variable.withString(
                summary['voiesAdministration'] as String? ?? '',
              ),
              Variable.withString(summary['princepsBrandName'] as String),
              Variable.withString(summary['procedureType'] as String? ?? ''),
              Variable.withInt(summary['titulaireId'] as int? ?? 0),
              Variable.withString(
                summary['conditionsPrescription'] as String? ?? '',
              ),
              Variable.withString(summary['dateAmm'] as String? ?? ''),
              Variable.withBool(summary['isSurveillance'] as bool? ?? false),
              Variable.withString(summary['atcCode'] as String? ?? ''),
              Variable.withString(summary['status'] as String? ?? ''),
              Variable.withReal(summary['priceMin'] as double? ?? 0.0),
              Variable.withReal(summary['priceMax'] as double? ?? 0.0),
              Variable.withString(
                summary['aggregatedConditions'] as String? ?? '[]',
              ),
              Variable.withString(summary['ansmAlertUrl'] as String? ?? ''),
              Variable.withBool(summary['isHospital'] as bool? ?? false),
              Variable.withBool(summary['isDental'] as bool? ?? false),
              Variable.withBool(summary['isList1'] as bool? ?? false),
              Variable.withBool(summary['isList2'] as bool? ?? false),
              Variable.withBool(summary['isNarcotic'] as bool? ?? false),
              Variable.withBool(summary['isException'] as bool? ?? false),
              Variable.withBool(summary['isRestricted'] as bool? ?? false),
              Variable.withBool(summary['isOtc'] as bool? ?? true),
              Variable.withString(summary['smrNiveau'] as String? ?? ''),
              Variable.withString(summary['smrDate'] as String? ?? ''),
              Variable.withString(summary['asmrNiveau'] as String? ?? ''),
              Variable.withString(summary['asmrDate'] as String? ?? ''),
              Variable.withString(summary['urlNotice'] as String? ?? ''),
              Variable.withBool(summary['hasSafetyAlert'] as bool? ?? false),
              Variable.withString(
                summary['representativeCip'] as String? ?? '',
              ),
            ],
            updates: {database.medicamentSummary},
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
