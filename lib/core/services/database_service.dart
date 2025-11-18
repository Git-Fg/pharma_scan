// lib/core/services/database_service.dart
import 'dart:convert';
import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart' hide Medicament;
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/utils/dosage_utils.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';
import 'package:pharma_scan/features/explorer/models/cluster_summary_model.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_summary_model.dart';
import 'package:pharma_scan/features/explorer/models/grouped_by_product_model.dart';
import 'package:pharma_scan/features/explorer/models/product_group_classification_model.dart';
import 'package:pharma_scan/features/explorer/models/search_candidate_model.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';

class DatabaseService {
  static const _maxSqlVariables = 900;
  final AppDatabase _db = sl<AppDatabase>();

  // WHY: Provides access to the database for custom operations
  // Used by DataInitializationService for aggregation logic
  AppDatabase get database => _db;

  // WHY: Unified method to handle both generic and princeps scans.
  // Uses MedicamentSummary table for faster lookups and pre-calculated data.
  // Hardened against "chameleon" medications that appear as both princeps and generic
  // in different groups. Business rule: princeps status in ANY group wins.
  Future<ScanResult?> getScanResultByCip(String codeCip) async {
    // First, get the CIS code for this CIP
    final medicamentQuery = _db.select(_db.medicaments)
      ..where((tbl) => tbl.codeCip.equals(codeCip));
    final medicamentRow = await medicamentQuery.getSingleOrNull();

    if (medicamentRow == null) return null;

    final cisCode = medicamentRow.cisCode;

    // Get the summary data from MedicamentSummary table
    final summaryQuery = _db.select(_db.medicamentSummary)
      ..where((tbl) => tbl.cisCode.equals(cisCode));
    final summaryRow = await summaryQuery.getSingleOrNull();

    if (summaryRow == null) return null;

    // Get full medicament details from specialites
    final specialiteQuery = _db.select(_db.specialites)
      ..where((tbl) => tbl.cisCode.equals(cisCode));
    final specialiteRow = await specialiteQuery.getSingleOrNull();

    if (specialiteRow == null) return null;

    // Get active principles for this medication
    final principesQuery = _db.select(_db.principesActifs)
      ..where((tbl) => tbl.codeCip.equals(codeCip));
    final principesData = await principesQuery.get();
    final principes = principesData.map((row) => row.principe).toList();

    final commonPrincipes = _decodeCommonPrincipesList(
      summaryRow.principesActifsCommuns,
    );

    // WHY: On récupère le premier dosage pour le médicament scanné (le plus représentatif)
    final firstPrincipeData = principesData.isNotEmpty
        ? principesData.first
        : null;

    final scannedMedicament = Medicament(
      nom: specialiteRow.nomSpecialite,
      codeCip: codeCip,
      principesActifs: commonPrincipes.isNotEmpty ? commonPrincipes : principes,
      titulaire: parseMainTitulaire(specialiteRow.titulaire),
      formePharmaceutique: specialiteRow.formePharmaceutique,
      dosage: parseDecimalValue(firstPrincipeData?.dosage),
      dosageUnit: firstPrincipeData?.dosageUnit,
      conditionsPrescription: specialiteRow.conditionsPrescription,
    );

    final groupId = summaryRow.groupId;
    if (groupId == null) {
      // Standalone medication without a group
      return null;
    }

    // Get all group members from MedicamentSummary
    final groupMembersQuery = _db.select(_db.medicamentSummary)
      ..where((tbl) => tbl.groupId.equals(groupId));
    final groupMembers = await groupMembersQuery.get();

    if (summaryRow.isPrinceps) {
      // Scanned a PRINCEPS
      final genericSummaries = groupMembers
          .where((row) => !row.isPrinceps)
          .toList();

      // Get generic lab names
      final genericCisCodes = genericSummaries.map((s) => s.cisCode).toList();
      if (genericCisCodes.isNotEmpty) {
        final genericLabsQuery = _db.select(_db.specialites)
          ..where((tbl) => tbl.cisCode.isIn(genericCisCodes));
        final genericLabsRows = await genericLabsQuery.get();

        final genericLabs = genericLabsRows
            .map((row) => row.titulaire)
            .where((titulaire) => titulaire != null && titulaire.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();

        return ScanResult.princeps(
          princeps: scannedMedicament,
          moleculeName: commonPrincipes.isNotEmpty
              ? commonPrincipes.first
              : (principes.isNotEmpty ? principes.first : 'N/A'),
          genericLabs: genericLabs,
          groupId: groupId,
        );
      } else {
        return ScanResult.princeps(
          princeps: scannedMedicament,
          moleculeName: commonPrincipes.isNotEmpty
              ? commonPrincipes.first
              : (principes.isNotEmpty ? principes.first : 'N/A'),
          genericLabs: [],
          groupId: groupId,
        );
      }
    } else {
      // Scanned a GENERIC
      final princepsSummaries = groupMembers
          .where((row) => row.isPrinceps)
          .toList();

      // Get associated princeps details
      final princepsCisCodes = princepsSummaries.map((s) => s.cisCode).toList();
      if (princepsCisCodes.isNotEmpty) {
        final princepsQuery = _db.select(_db.specialites).join([
          innerJoin(
            _db.medicaments,
            _db.medicaments.cisCode.equalsExp(_db.specialites.cisCode),
          ),
        ])..where(_db.specialites.cisCode.isIn(princepsCisCodes));

        final princepsRows = await princepsQuery.get();

        final associatedPrinceps = princepsRows.map((row) {
          final medData = row.readTable(_db.medicaments);
          final specData = row.readTable(_db.specialites);
          return Medicament(
            nom: specData.nomSpecialite,
            codeCip: medData.codeCip,
            principesActifs: [],
            conditionsPrescription: specData.conditionsPrescription,
          );
        }).toList();

        return ScanResult.generic(
          medicament: scannedMedicament,
          associatedPrinceps: associatedPrinceps,
          groupId: groupId,
        );
      } else {
        return ScanResult.generic(
          medicament: scannedMedicament,
          associatedPrinceps: [],
          groupId: groupId,
        );
      }
    }
  }

  Future<List<SearchCandidate>> getAllSearchCandidates() async {
    final rows = await _db
        .customSelect(
          '''
          SELECT
            ms.cis_code,
            ms.nom_canonique,
            ms.is_princeps,
            ms.group_id,
            ms.principes_actifs_communs,
            ms.princeps_de_reference,
            ms.forme_pharmaceutique,
            ms.procedure_type,
            ms.titulaire,
            ms.conditions_prescription,
            (
              SELECT code_cip
              FROM medicaments m
              WHERE m.cis_code = ms.cis_code
              LIMIT 1
            ) AS representative_cip
          FROM medicament_summary ms
          ORDER BY ms.nom_canonique COLLATE NOCASE
          ''',
          readsFrom: {_db.medicamentSummary, _db.medicaments},
        )
        .get();

    return rows.map((row) {
      final commonPrinciples = _decodeCommonPrincipesList(
        row.read<String>('principes_actifs_communs'),
      );
      final representativeCip =
          row.read<String?>('representative_cip') ??
          row.read<String>('cis_code');
      final formePharmaceutique = row.read<String?>('forme_pharmaceutique');

      final medicament = Medicament(
        nom: row.read<String>('nom_canonique'),
        codeCip: representativeCip,
        principesActifs: commonPrinciples,
        titulaire: parseMainTitulaire(row.read<String?>('titulaire')),
        formePharmaceutique: formePharmaceutique,
        conditionsPrescription: row.read<String?>('conditions_prescription'),
      );

      return SearchCandidate(
        cisCode: row.read<String>('cis_code'),
        nomCanonique: row.read<String>('nom_canonique'),
        isPrinceps: row.read<int>('is_princeps') == 1,
        groupId: row.read<String?>('group_id'),
        commonPrinciples: commonPrinciples,
        princepsDeReference: row.read<String>('princeps_de_reference'),
        formePharmaceutique: formePharmaceutique,
        procedureType: row.read<String?>('procedure_type'),
        medicament: medicament,
      );
    }).toList();
  }

  Future<ProductGroupClassification?> classifyProductGroup(
    String groupId,
  ) async {
    // WHY: Join with MedicamentSummary to access pre-computed cleaned names (nomCanonique)
    // from the parser. This implements Source of Truth 1 (The Parser) in the Triangulation Strategy.
    final groupMembersQuery = _db.select(_db.specialites).join([
      innerJoin(
        _db.medicaments,
        _db.medicaments.cisCode.equalsExp(_db.specialites.cisCode),
      ),
      innerJoin(
        _db.groupMembers,
        _db.groupMembers.codeCip.equalsExp(_db.medicaments.codeCip),
      ),
      innerJoin(
        _db.medicamentSummary,
        _db.medicamentSummary.cisCode.equalsExp(_db.specialites.cisCode),
      ),
    ])..where(_db.groupMembers.groupId.equals(groupId));

    final memberRows = await groupMembersQuery.get();
    if (memberRows.isEmpty) return null;

    final memberCips = memberRows
        .map((row) => row.readTable(_db.medicaments).codeCip)
        .toSet();
    final principesByCip = await _getPrincipesActifsByCip(memberCips);

    final princeps = <Medicament>[];
    final generics = <Medicament>[];
    final formsSet = <String>{};
    final dosageLabels = <String>{};

    for (final row in memberRows) {
      final medData = row.readTable(_db.medicaments);
      final specData = row.readTable(_db.specialites);
      final memberData = row.readTable(_db.groupMembers);
      final summaryData = row.readTable(_db.medicamentSummary);

      final principesData =
          principesByCip[medData.codeCip] ?? const <PrincipesActif>[];
      final firstPrincipe = principesData.isNotEmpty
          ? principesData.first
          : null;

      // WHY: Use nomCanonique from MedicamentSummary (pre-cleaned by parser with official form/lab hints)
      // instead of raw nomSpecialite. This implements the Triangulation Strategy's Source of Truth 1.
      final medicament = Medicament(
        nom: summaryData.nomCanonique,
        codeCip: medData.codeCip,
        principesActifs: principesData.map((p) => p.principe).toList(),
        titulaire: parseMainTitulaire(specData.titulaire),
        formePharmaceutique: specData.formePharmaceutique,
        dosage: parseDecimalValue(firstPrincipe?.dosage),
        dosageUnit: firstPrincipe?.dosageUnit,
        conditionsPrescription: specData.conditionsPrescription,
      );

      final dosageLabel = _formatDosageLabel(
        medicament.dosage,
        medicament.dosageUnit,
      );
      if (dosageLabel != null) {
        dosageLabels.add(dosageLabel);
      }

      final form = specData.formePharmaceutique?.trim();
      if (form != null && form.isNotEmpty) {
        formsSet.add(form);
      }

      if (memberData.type == 0) {
        princeps.add(medicament);
      } else {
        generics.add(medicament);
      }
    }

    final commonPrincipesMap = await _getCommonPrincipesForGroups({groupId});
    // WHY: Sanitization is already applied in _getCommonPrincipesForGroups
    final commonPrincipes = commonPrincipesMap[groupId] ?? const <String>[];

    // WHY: Identify reference princeps to derive group-level defaults.
    // Since drugs in the same Generic Group are therapeutically equivalent,
    // we can safely use the princeps' properties to fill gaps in generic data.
    // The princeps name is already cleaned (nomCanonique from MedicamentSummary),
    // so we use it directly without re-processing.
    final princepsReference = princeps.isNotEmpty ? princeps.first : null;
    final groupCanonicalName = princepsReference != null
        ? princepsReference.nom
        : (commonPrincipes.isNotEmpty
              ? commonPrincipes.join(' + ')
              : 'Inconnu');
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

    final relatedPrincepsList = await _findRelatedPrinceps(
      groupId,
      commonPrincipes,
    );
    final groupedRelatedPrinceps = _groupMedicamentsByProduct(
      relatedPrincepsList,
      groupCanonicalName: groupCanonicalName,
      groupPrimaryDosage: groupPrimaryDosage,
    );

    final distinctFormulations = formsSet.toList()..sort();

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
      distinctFormulations: distinctFormulations,
      princeps: groupedPrinceps,
      generics: groupedGenerics,
      relatedPrinceps: groupedRelatedPrinceps,
    );
  }

  Future<Map<String, List<PrincipesActif>>> _getPrincipesActifsByCip(
    Set<String> codeCips,
  ) async {
    if (codeCips.isEmpty) return {};

    final results = <String, List<PrincipesActif>>{};
    final cipList = codeCips.toList();

    for (var i = 0; i < cipList.length; i += _maxSqlVariables) {
      final chunk = cipList.sublist(
        i,
        (i + _maxSqlVariables > cipList.length)
            ? cipList.length
            : i + _maxSqlVariables,
      );
      if (chunk.isEmpty) continue;

      final query = _db.select(_db.principesActifs)
        ..where((tbl) => tbl.codeCip.isIn(chunk));
      final rows = await query.get();

      for (final row in rows) {
        results.putIfAbsent(row.codeCip, () => []).add(row);
      }
    }

    return results;
  }

  // WHY: Groups medicaments by product name and dosage using Triangulation Strategy.
  // Source 1 (Parser): Uses pre-cleaned names from MedicamentSummary.nomCanonique.
  // Source 2 (Database): Uses structured dosage from principes_actifs table.
  // Source 3 (Group Context): Falls back to reference princeps properties when individual
  // data is incomplete. This leverages the legal equivalence of drugs within the same
  // Generic Group to fill gaps safely.
  List<GroupedByProduct> _groupMedicamentsByProduct(
    List<Medicament> medicaments, {
    required String groupCanonicalName,
    required Decimal? groupPrimaryDosage,
  }) {
    if (medicaments.isEmpty) return [];

    final buckets = <String, _ProductGroupBucket>{};

    for (final medicament in medicaments) {
      // Triangulate Name: Use cleaned name directly (from parser via MedicamentSummary).
      // Fallback to group standard only if name is too short (parser stripped everything).
      String nameToUse = medicament.nom.trim();
      if (nameToUse.length < 3) {
        nameToUse = groupCanonicalName;
      }

      // Triangulate Dosage: Use structured DB column (Source 2), fallback to group standard (Source 3).
      final dosageToUse = medicament.dosage ?? groupPrimaryDosage;
      final unitToUse = medicament.dosageUnit;

      final dosageKey = dosageToUse?.toString() ?? 'null';
      final unitKey = unitToUse?.toUpperCase() ?? 'null';
      final key = '${nameToUse.toUpperCase()}|$dosageKey|$unitKey';

      final bucket = buckets.putIfAbsent(
        key,
        () => _ProductGroupBucket(
          productName: nameToUse,
          dosage: dosageToUse,
          dosageUnit: unitToUse,
        ),
      );

      final lab = (medicament.titulaire?.trim().isNotEmpty ?? false)
          ? medicament.titulaire!.trim()
          : 'Laboratoire Inconnu';
      bucket.laboratories.add(lab);
      bucket.medicaments.add(medicament);
    }

    final groupedProducts = buckets.values.map((bucket) {
      final laboratories = bucket.laboratories.toList()..sort();
      final presentations = List<Medicament>.from(bucket.medicaments)
        ..sort((a, b) => a.nom.compareTo(b.nom));

      return GroupedByProduct(
        productName: bucket.productName,
        dosage: bucket.dosage,
        dosageUnit: bucket.dosageUnit,
        laboratories: laboratories,
        medicaments: presentations,
      );
    }).toList()..sort((a, b) => a.productName.compareTo(b.productName));

    return groupedProducts;
  }

  // WHY: Build synthetic title using only deterministic data sources.
  // Removed fallbackLabel (raw generique_groups.libelle) to ensure 100% data consistency.
  // Title is built from: canonicalName (algorithmic) → fallbackPrincipes (deterministic) → "Groupe $groupId".
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

  String? _formatDosageLabel(Decimal? dosage, String? unit) {
    return formatDosageLabel(dosage: dosage, unit: unit);
  }

  // WHY: Finds related princeps from groups that contain ALL of the current group's
  // active ingredients PLUS at least one additional ingredient. This identifies
  // "associated therapies" - medications that share the same base ingredients
  // but have additional active components.
  Future<List<Medicament>> _findRelatedPrinceps(
    String groupId,
    List<String> commonPrincipes,
  ) async {
    if (commonPrincipes.isEmpty) return const [];

    // WHY: Use the generated query from queries.drift
    // Parameters: groupId (appears twice), commonPrincipes list (appears twice)
    final relatedGroupsRows = await _db
        .findRelatedPrinceps(groupId, groupId, commonPrincipes, commonPrincipes)
        .get();
    if (relatedGroupsRows.isEmpty) return const [];

    final relatedCips = relatedGroupsRows
        .map((row) => row.codeCip)
        .toSet()
        .toList();

    if (relatedCips.isEmpty) return const [];

    // Get full medicament data for related princeps
    final medicamentsQuery = _db.select(_db.medicaments).join([
      innerJoin(
        _db.specialites,
        _db.specialites.cisCode.equalsExp(_db.medicaments.cisCode),
      ),
    ])..where(_db.medicaments.codeCip.isIn(relatedCips));

    final medicamentRows = await medicamentsQuery.get();

    // Get principes actifs for all related medicaments
    final principesByCip = await _getPrincipesActifsByCip(relatedCips.toSet());

    final relatedPrincepsList = <Medicament>[];
    for (final row in medicamentRows) {
      final medData = row.readTable(_db.medicaments);
      final specData = row.readTable(_db.specialites);
      final principesData = principesByCip[medData.codeCip] ?? const [];
      final firstPrincipe = principesData.isNotEmpty
          ? principesData.first
          : null;

      relatedPrincepsList.add(
        Medicament(
          nom: specData.nomSpecialite,
          codeCip: medData.codeCip,
          principesActifs: principesData.map((p) => p.principe).toList(),
          dosage: parseDecimalValue(firstPrincipe?.dosage),
          dosageUnit: firstPrincipe?.dosageUnit,
          titulaire: parseMainTitulaire(specData.titulaire),
          formePharmaceutique: specData.formePharmaceutique,
          conditionsPrescription: specData.conditionsPrescription,
        ),
      );
    }

    return relatedPrincepsList;
  }

  // WHY: Provides a deterministic way to reset the persisted database before reloading BDPM data or starting an integration test run.
  Future<void> clearDatabase() async {
    await _db.delete(_db.medicamentSummary).go();
    await _db.delete(_db.groupMembers).go();
    await _db.delete(_db.generiqueGroups).go();
    await _db.delete(_db.principesActifs).go();
    await _db.delete(_db.medicaments).go();
    await _db.delete(_db.specialites).go();
  }

  Future<void> insertBatchData({
    required List<Map<String, dynamic>> specialites,
    required List<Map<String, dynamic>> medicaments,
    required List<Map<String, dynamic>> principes,
    required List<Map<String, dynamic>> generiqueGroups,
    required List<Map<String, dynamic>> groupMembers,
  }) async {
    await _db.batch((batch) {
      batch.insertAll(
        _db.specialites,
        specialites.map(
          (row) => SpecialitesCompanion(
            cisCode: Value(row['cis_code'] as String),
            nomSpecialite: Value(row['nom_specialite'] as String),
            procedureType: Value(row['procedure_type'] as String),
            formePharmaceutique: Value(row['forme_pharmaceutique'] as String?),
            etatCommercialisation: Value(
              row['etat_commercialisation'] as String?,
            ),
            titulaire: Value(row['titulaire'] as String?),
            conditionsPrescription: Value(
              row['conditions_prescription'] as String?,
            ),
          ),
        ),
        mode: InsertMode.replace,
      );
      batch.insertAll(
        _db.medicaments,
        medicaments.map(
          (row) => MedicamentsCompanion(
            codeCip: Value(row['code_cip'] as String),
            // WHY: Removed nom field - specialites table is the single source of truth for medication names.
            cisCode: Value(row['cis_code'] as String),
          ),
        ),
        mode: InsertMode.replace,
      );
      batch.insertAll(
        _db.principesActifs,
        principes.map(
          (row) => PrincipesActifsCompanion(
            codeCip: Value(row['code_cip'] as String),
            principe: Value(row['principe'] as String),
            dosage: Value(row['dosage'] as String?),
            dosageUnit: Value(row['dosage_unit'] as String?),
          ),
        ),
      );
      batch.insertAll(
        _db.generiqueGroups,
        generiqueGroups.map(
          (row) => GeneriqueGroupsCompanion(
            groupId: Value(row['group_id'] as String),
            libelle: Value(row['libelle'] as String),
          ),
        ),
        mode: InsertMode.replace,
      );
      batch.insertAll(
        _db.groupMembers,
        groupMembers.map(
          (row) => GroupMembersCompanion(
            codeCip: Value(row['code_cip'] as String),
            groupId: Value(row['group_id'] as String),
            type: Value(row['type'] as int),
          ),
        ),
        mode: InsertMode.replace,
      );
    });
  }

  // WHY: Retrieves global statistics for the dashboard.
  // Provides overview of database content: princeps count, generics count, principles count, and average generics per principle.
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final totalMedicamentsQuery = _db.selectOnly(_db.medicaments)
      ..addColumns([_db.medicaments.codeCip.count()]);
    final totalMedicaments = await totalMedicamentsQuery.getSingle();

    final totalGeneriquesQuery = _db.selectOnly(_db.groupMembers)
      ..addColumns([_db.groupMembers.codeCip.count()])
      ..where(_db.groupMembers.type.equals(1));
    final totalGeneriques = await totalGeneriquesQuery.getSingle();

    final totalPrincipesQuery = _db.selectOnly(_db.principesActifs)
      ..addColumns([_db.principesActifs.principe.count(distinct: true)]);
    final totalPrincipes = await totalPrincipesQuery.getSingle();

    final countMeds =
        totalMedicaments.read(_db.medicaments.codeCip.count()) ?? 0;
    final countGens =
        totalGeneriques.read(_db.groupMembers.codeCip.count()) ?? 0;
    final countPrincipes =
        totalPrincipes.read(
          _db.principesActifs.principe.count(distinct: true),
        ) ??
        0;

    final countPrinceps = countMeds - countGens;

    // WHY: Calculate average generics per principle for statistical insight.
    double ratioGenPerPrincipe = 0.0;
    if (countPrincipes > 0) {
      ratioGenPerPrincipe = countGens / countPrincipes;
    }

    return {
      'total_princeps': countPrinceps,
      'total_generiques': countGens,
      'total_principes': countPrincipes,
      'avg_gen_per_principe': ratioGenPerPrincipe,
    };
  }

  Future<List<ClusterSummary>> getClusterSummaries({
    int limit = 40,
    int offset = 0,
  }) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT
            cluster_key,
            princeps_brand_name,
            MIN(principes_actifs_communs) AS principes_payload,
            COUNT(DISTINCT group_id) AS group_count,
            COUNT(*) AS member_count
          FROM medicament_summary
          WHERE cluster_key != ''
            AND group_id IS NOT NULL
          GROUP BY cluster_key, princeps_brand_name
          ORDER BY princeps_brand_name COLLATE NOCASE
          LIMIT ? OFFSET ?
          ''',
          variables: [Variable.withInt(limit), Variable.withInt(offset)],
        )
        .get();

    return rows.map((row) {
      final principles = _decodeCommonPrincipesList(
        row.read<String>('principes_payload'),
      );

      return ClusterSummary(
        clusterKey: row.read<String>('cluster_key'),
        princepsBrandName: row.read<String>('princeps_brand_name'),
        activeIngredients: principles,
        groupCount: row.read<int>('group_count'),
        memberCount: row.read<int>('member_count'),
      );
    }).toList();
  }

  Future<List<GenericGroupSummary>> getClusterGroupSummaries(
    String clusterKey,
  ) async {
    final rows = await _db
        .customSelect(
          '''
          SELECT DISTINCT
            group_id,
            princeps_de_reference,
            principes_actifs_communs AS common_principes
          FROM medicament_summary
          WHERE cluster_key = ?
            AND group_id IS NOT NULL
          GROUP BY group_id, princeps_de_reference, principes_actifs_communs
          ORDER BY princeps_de_reference COLLATE NOCASE
          ''',
          variables: [Variable.withString(clusterKey)],
        )
        .get();

    return rows.map((row) {
      final commonPrincipesRaw = row.read<String>('common_principes');
      final commonPrincipes = _formatCommonPrincipes(commonPrincipesRaw);
      final princepsReference = row.read<String>('princeps_de_reference');
      final groupId = row.read<String>('group_id');

      return GenericGroupSummary(
        groupId: groupId,
        commonPrincipes: commonPrincipes,
        princepsReferenceName: princepsReference,
      );
    }).toList();
  }

  Future<List<GenericGroupSummary>> getGenericGroupSummaries({
    List<String>? formKeywords,
    List<String>? excludeKeywords,
    List<String>? procedureTypeKeywords,
    int limit = 100,
    int offset = 0,
  }) async {
    // WHY: Use the new MedicamentSummary table for much simpler and faster queries
    // This eliminates complex joins and Dart-based grouping logic

    // Build WHERE clause based on form keywords or procedure type
    String whereClause = '';
    if (procedureTypeKeywords != null && procedureTypeKeywords.isNotEmpty) {
      final procedureConditions = procedureTypeKeywords
          .map((kw) => "s.procedure_type LIKE '%${kw.replaceAll("'", "''")}%'")
          .join(' OR ');
      whereClause =
          '''
WHERE EXISTS (
  SELECT 1
  FROM specialites s
  WHERE s.cis_code = medicament_summary.cis_code
    AND ($procedureConditions)
)
''';
    } else if (formKeywords != null && formKeywords.isNotEmpty) {
      final formConditions = formKeywords
          .map(
            (kw) => "forme_pharmaceutique LIKE '%${kw.replaceAll("'", "''")}%'",
          )
          .join(' OR ');

      final excludeConditions = excludeKeywords?.isNotEmpty == true
          ? excludeKeywords!
                .map(
                  (kw) =>
                      "forme_pharmaceutique NOT LIKE '%${kw.replaceAll("'", "''")}%'",
                )
                .join(' AND ')
          : '';

      whereClause =
          "WHERE ($formConditions)${excludeConditions.isNotEmpty ? ' AND $excludeConditions' : ''}";
    }

    // Query: MedicamentSummary table directly
    final query = _db.customSelect(
      '''
      SELECT DISTINCT
        principes_actifs_communs as common_principes,
        princeps_de_reference,
        group_id
      FROM medicament_summary
      $whereClause
      ORDER BY nom_canonique
      LIMIT ? OFFSET ?
    ''',
      variables: [Variable.withInt(limit), Variable.withInt(offset)],
    );

    final results = await query.get();

    // Convert to GenericGroupSummary objects
    return results.map((row) {
      final commonPrincipesRaw = row.read<String>('common_principes');
      final commonPrincipes = _formatCommonPrincipes(commonPrincipesRaw);
      final princepsReference = row.read<String>('princeps_de_reference');
      final groupId = row.read<String>('group_id');

      return GenericGroupSummary(
        groupId: groupId,
        commonPrincipes: commonPrincipes,
        princepsReferenceName: princepsReference,
      );
    }).toList();
  }

  String _formatCommonPrincipes(String? raw) {
    final principles = _decodeCommonPrincipesList(raw);
    if (principles.isEmpty) return '';
    return principles.join(', ');
  }

  List<String> _decodeCommonPrincipesList(String? raw) {
    if (raw == null || raw.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((item) => item.toString())
            .where((value) => value.trim().isNotEmpty)
            .toList();
      }
      final trimmed = raw.trim();
      return trimmed.isEmpty ? const <String>[] : [trimmed];
    } catch (_) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? const <String>[] : [trimmed];
    }
  }

  Future<Map<String, List<String>>> _getCommonPrincipesForGroups(
    Set<String> groupIds,
  ) async {
    if (groupIds.isEmpty) return {};

    final results = <String, List<String>>{};
    final groupList = groupIds.toList();

    for (var i = 0; i < groupList.length; i += _maxSqlVariables) {
      final chunk = groupList.sublist(
        i,
        (i + _maxSqlVariables > groupList.length)
            ? groupList.length
            : i + _maxSqlVariables,
      );

      if (chunk.isEmpty) continue;

      // WHY: Use the generated query from queries.drift
      // The query uses the list parameter twice (in two CTEs), so we pass it twice
      final rows = await _db.getCommonPrincipesForGroups(chunk, chunk).get();
      for (final row in rows) {
        final groupId = row.groupId;
        final principe = row.principe;

        // WHY: Sanitize active principle to remove dosage, units, and formulation keywords
        final sanitizedPrinciple = sanitizeActivePrinciple(principe);
        if (sanitizedPrinciple.isNotEmpty) {
          results.putIfAbsent(groupId, () => []).add(sanitizedPrinciple);
        }
      }
    }

    return results;
  }

  Future<bool> hasExistingData() async {
    final totalGroupsQuery = _db.selectOnly(_db.generiqueGroups)
      ..addColumns([_db.generiqueGroups.groupId.count()]);
    final totalGroups = await totalGroupsQuery.getSingle();
    final count = totalGroups.read(_db.generiqueGroups.groupId.count()) ?? 0;

    return count > 0;
  }
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
