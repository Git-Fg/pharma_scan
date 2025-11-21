// lib/core/services/drift_database_service.dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart' hide Medicament;
import 'package:pharma_scan/core/database/database.dart' as drift_db;
import 'package:pharma_scan/core/database/mappers.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_entity.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';

// WHY: Helper for customSelect results (raw SQL bypasses TypeConverter)
class DriftDatabaseService {
  DriftDatabaseService(this._db);

  final AppDatabase _db;

  Future<AppSetting> getSettings() async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((tbl) => tbl.id.equals(1))).getSingleOrNull();
    if (row != null) return row;

    await _db
        .into(_db.appSettings)
        .insert(
          const AppSettingsCompanion(id: Value(1)),
          mode: InsertMode.insertOrIgnore,
        );

    return (_db.select(
      _db.appSettings,
    )..where((tbl) => tbl.id.equals(1))).getSingle();
  }

  Stream<AppSetting> watchSettings() {
    final selectSettings = (_db.select(_db.appSettings)
      ..where((tbl) => tbl.id.equals(1)));

    return selectSettings.watchSingleOrNull().asyncMap((row) async {
      if (row != null) return row;

      await _db
          .into(_db.appSettings)
          .insert(
            const AppSettingsCompanion(id: Value(1)),
            mode: InsertMode.insertOrIgnore,
          );
      return (_db.select(
        _db.appSettings,
      )..where((tbl) => tbl.id.equals(1))).getSingle();
    });
  }

  Future<String?> getBdpmVersion() async {
    final settings = await getSettings();
    return settings.bdpmVersion;
  }

  Future<void> updateBdpmVersion(String? version) async {
    await (_db.update(_db.appSettings)..where((tbl) => tbl.id.equals(1))).write(
      AppSettingsCompanion(bdpmVersion: Value(version)),
    );
  }

  Future<DateTime?> getLastSyncTime() async {
    final settings = await getSettings();
    final millis = settings.lastSyncEpoch;
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> updateTheme(String mode) async {
    await (_db.update(_db.appSettings)..where((tbl) => tbl.id.equals(1))).write(
      AppSettingsCompanion(themeMode: Value(mode)),
    );
  }

  Future<void> updateSyncFrequency(String frequency) async {
    await (_db.update(_db.appSettings)..where((tbl) => tbl.id.equals(1))).write(
      AppSettingsCompanion(updateFrequency: Value(frequency)),
    );
  }

  Future<void> updateSyncTimestamp(int epochMillis) async {
    await (_db.update(_db.appSettings)..where((tbl) => tbl.id.equals(1))).write(
      AppSettingsCompanion(lastSyncEpoch: Value(epochMillis)),
    );
  }

  Future<Map<String, String>> getSourceHashes() async {
    final settings = await getSettings();
    return _decodeStringMap(settings.sourceHashes);
  }

  Future<void> saveSourceHashes(Map<String, String> hashes) async {
    await (_db.update(_db.appSettings)..where((tbl) => tbl.id.equals(1))).write(
      AppSettingsCompanion(sourceHashes: Value(jsonEncode(hashes))),
    );
  }

  Future<Map<String, DateTime>> getSourceDates() async {
    final settings = await getSettings();
    final raw = _decodeStringMap(settings.sourceDates);
    final result = <String, DateTime>{};
    for (final entry in raw.entries) {
      final parsed = DateTime.tryParse(entry.value);
      if (parsed != null) {
        result[entry.key] = parsed;
      }
    }
    return result;
  }

  Future<void> saveSourceDates(Map<String, DateTime> dates) async {
    final encoded = dates.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    );
    await (_db.update(_db.appSettings)..where((tbl) => tbl.id.equals(1))).write(
      AppSettingsCompanion(sourceDates: Value(jsonEncode(encoded))),
    );
  }

  Future<void> clearSourceMetadata() async {
    await (_db.update(_db.appSettings)..where((tbl) => tbl.id.equals(1))).write(
      const AppSettingsCompanion(
        sourceHashes: Value('{}'),
        sourceDates: Value('{}'),
      ),
    );
  }

  Future<void> resetSettingsMetadata() async {
    await (_db.update(_db.appSettings)..where((tbl) => tbl.id.equals(1))).write(
      const AppSettingsCompanion(
        bdpmVersion: Value(null),
        lastSyncEpoch: Value(null),
      ),
    );
  }

  Map<String, String> _decodeStringMap(String raw) {
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        );
      }
    } catch (_) {
      return {};
    }
    return {};
  }

  // WHY: Provides access to the database for custom operations
  // Used by DataInitializationService for aggregation logic
  AppDatabase get database => _db;

  // WHY: Unified method to handle both generic and princeps scans.
  // Uses MedicamentSummary table for faster lookups and pre-calculated data.
  // Hardened against "chameleon" medications that appear as both princeps and generic
  // in different groups. Business rule: princeps status in ANY group wins.
  // Optimized to use joins instead of sequential queries for better performance.
  // Returns ScanResult domain entities consumed by the scanner repository.
  Future<ScanResult?> getScanResultByCip(String codeCip) async {
    LoggerService.db('Lookup scan result for CIP $codeCip');
    final detailedRow = await (_db.select(
      _db.detailedScanResults,
    )..where((tbl) => tbl.codeCip.equals(codeCip))).getSingleOrNull();
    if (detailedRow == null) return null;

    final summaryRow = await (_db.select(
      _db.medicamentSummary,
    )..where((tbl) => tbl.cisCode.equals(detailedRow.cisCode))).getSingle();

    final principesRows = await (_db.select(
      _db.principesActifs,
    )..where((tbl) => tbl.codeCip.equals(codeCip))).get();

    final medicament = detailedRow.toDetailedMedicament(
      summaryRow: summaryRow,
      principesRows: principesRows,
    );

    final groupId = summaryRow.groupId;
    if (groupId == null) {
      return ScanResult.standalone(medicament: medicament);
    }

    final groupMembers = await (_db.select(
      _db.medicamentSummary,
    )..where((tbl) => tbl.groupId.equals(groupId))).get();

    if (summaryRow.isPrinceps) {
      final moleculeName = _resolveMoleculeName(
        summaryRow.principesActifsCommuns,
        principesRows,
      );
      final genericLabs = await _findGenericLabs(groupMembers);

      return ScanResult.princeps(
        princeps: medicament,
        moleculeName: moleculeName,
        genericLabs: genericLabs,
        groupId: groupId,
      );
    }

    final associatedPrinceps = await _findAssociatedPrinceps(groupMembers);
    return ScanResult.generic(
      medicament: medicament,
      associatedPrinceps: associatedPrinceps,
      groupId: groupId,
    );
  }

  String _resolveMoleculeName(
    List<String> commonPrincipes,
    List<drift_db.PrincipesActif> principesRows,
  ) {
    if (commonPrincipes.isNotEmpty) return commonPrincipes.first;
    if (principesRows.isNotEmpty) return principesRows.first.principe;
    return 'N/A';
  }

  Future<List<String>> _findGenericLabs(
    List<drift_db.MedicamentSummaryData> groupMembers,
  ) async {
    final genericMembers = groupMembers
        .where((member) => !member.isPrinceps)
        .toList();
    if (genericMembers.isEmpty) return const [];

    final cisCodes = genericMembers.map((member) => member.cisCode).toList();
    final specialites = await (_db.select(
      _db.specialites,
    )..where((tbl) => tbl.cisCode.isIn(cisCodes))).get();

    final labs =
        specialites
            .map((row) => row.titulaire)
            .whereType<String>()
            .map(parseMainTitulaire)
            .where((titulaire) => titulaire.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return labs;
  }

  Future<List<Medicament>> _findAssociatedPrinceps(
    List<drift_db.MedicamentSummaryData> groupMembers,
  ) async {
    final princepsMembers = groupMembers
        .where((member) => member.isPrinceps)
        .toList();
    if (princepsMembers.isEmpty) return const [];

    final cisCodes = princepsMembers.map((member) => member.cisCode).toList();
    final joinedRows = await (_db.select(_db.specialites).join([
      innerJoin(
        _db.medicaments,
        _db.medicaments.cisCode.equalsExp(_db.specialites.cisCode),
      ),
    ])..where(_db.specialites.cisCode.isIn(cisCodes))).get();

    final princeps = <Medicament>[];
    for (final row in joinedRows) {
      final specRow = row.readTable(_db.specialites);
      final medRow = row.readTable(_db.medicaments);
      princeps.add(
        Medicament(
          nom: specRow.nomSpecialite,
          codeCip: medRow.codeCip,
          principesActifs: const [],
          titulaire: parseMainTitulaire(specRow.titulaire),
          formePharmaceutique: specRow.formePharmaceutique ?? '',
          conditionsPrescription: specRow.conditionsPrescription ?? '',
        ),
      );
    }

    return princeps;
  }

  // WHY: Returns all search candidates from MedicamentSummary table (the single source of truth).
  // Phase 2 aggregation populates this table with both grouped medications and standalone medications,
  // eliminating the need for separate standalone queries and redundant data fetching.
  Future<List<drift_db.MedicamentSummaryData>> getAllSearchCandidates() async {
    LoggerService.db('Loading all search candidates from medicament_summary');
    // Get all summary rows (includes both grouped and standalone medications)
    // TypeConverter handles principesActifsCommuns automatically
    return (_db.select(
      _db.medicamentSummary,
    )..orderBy([(tbl) => OrderingTerm.asc(tbl.nomCanonique)])).get();
  }

  Future<ProductGroupData?> classifyProductGroup(String groupId) async {
    LoggerService.db('Classifying product group $groupId');
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

    final memberDataList = <GroupMemberData>[];
    List<String> commonPrincipes = [];

    for (final row in memberRows) {
      final medData = row.readTable(_db.medicaments);
      final specData = row.readTable(_db.specialites);
      final memberData = row.readTable(_db.groupMembers);
      final summaryData = row.readTable(_db.medicamentSummary);

      memberDataList.add(
        GroupMemberData(
          medicamentRow: medData,
          specialiteRow: specData,
          groupMemberRow: memberData,
          summaryRow: summaryData,
        ),
      );

      // WHY: Extract common principles from the first summary row we find (they are identical for the group)
      if (commonPrincipes.isEmpty) {
        commonPrincipes = summaryData.principesActifsCommuns;
      }
    }

    // WHY: Find related princeps from other groups that contain ALL of the current group's
    // active ingredients PLUS at least one additional ingredient.
    final relatedPrincepsRows = await _findRelatedPrinceps(
      groupId,
      commonPrincipes,
    );

    // WHY: Get principes for related princeps as well
    final relatedCips = relatedPrincepsRows
        .map((row) => row.medicamentRow.codeCip)
        .toSet();
    final relatedPrincipesByCip = await _getPrincipesActifsByCip(relatedCips);
    principesByCip.addAll(relatedPrincipesByCip);

    return ProductGroupData(
      groupId: groupId,
      memberRows: memberDataList,
      principesByCip: principesByCip,
      commonPrincipes: commonPrincipes,
      relatedPrincepsRows: relatedPrincepsRows,
    );
  }

  // WHY: Find princeps from other groups that contain ALL of the current group's
  // active ingredients PLUS at least one additional ingredient.
  Future<List<GroupMemberData>> _findRelatedPrinceps(
    String groupId,
    List<String> commonPrincipes,
  ) async {
    if (commonPrincipes.isEmpty) return [];

    // WHY: Query the denormalized MedicamentSummary source of truth directly to
    // avoid redundant multi-table joins when filtering candidate rows.
    final summaryQuery = _db.select(_db.medicamentSummary)
      ..where(
        (tbl) => tbl.groupId.isNotValue(groupId) & tbl.isPrinceps.equals(true),
      );

    final summaryRows = await summaryQuery.get();
    if (summaryRows.isEmpty) return [];

    final candidateSummaries = <MedicamentSummaryData>[];
    for (final summary in summaryRows) {
      final rowPrincipes = summary.principesActifsCommuns;

      // WHY: Related therapies must contain all shared principles plus at least
      // one extra component to be considered an enriched princeps option.
      final hasAllCommon = commonPrincipes.every(rowPrincipes.contains);
      final hasAdditional = rowPrincipes.length > commonPrincipes.length;

      if (hasAllCommon && hasAdditional) {
        candidateSummaries.add(summary);
      }
    }

    if (candidateSummaries.isEmpty) return [];

    final relatedPrincepsRows = <GroupMemberData>[];
    final cisCodes = candidateSummaries.map((row) => row.cisCode).toList();

    // WHY: Hydrate the minimal set of rows (only confirmed matches) to keep the
    // join cost low. Drift 2.24.0+ handles large sets internally.
    final hydratedQuery = _db.select(_db.specialites).join([
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
    ])..where(_db.specialites.cisCode.isIn(cisCodes));

    final hydratedRows = await hydratedQuery.get();
    for (final row in hydratedRows) {
      relatedPrincepsRows.add(
        GroupMemberData(
          medicamentRow: row.readTable(_db.medicaments),
          specialiteRow: row.readTable(_db.specialites),
          groupMemberRow: row.readTable(_db.groupMembers),
          summaryRow: row.readTable(_db.medicamentSummary),
        ),
      );
    }

    return relatedPrincepsRows;
  }

  Future<Map<String, List<PrincipesActif>>> _getPrincipesActifsByCip(
    Set<String> codeCips,
  ) async {
    if (codeCips.isEmpty) return {};

    final results = <String, List<PrincipesActif>>{};
    final cipList = codeCips.toList();

    // WHY: Drift 2.24.0+ handles large sets internally, so manual chunking is no longer needed.
    final query = _db.select(_db.principesActifs)
      ..where((tbl) => tbl.codeCip.isIn(cipList));
    final rows = await query.get();

    for (final row in rows) {
      results.putIfAbsent(row.codeCip, () => []).add(row);
    }

    return results;
  }

  // WHY: Provides a deterministic way to reset the persisted database before reloading BDPM data or starting an integration test run.
  Future<void> clearDatabase() async {
    await _db.delete(_db.medicamentSummary).go();
    await _db.delete(_db.groupMembers).go();
    await _db.delete(_db.generiqueGroups).go();
    await _db.delete(_db.principesActifs).go();
    await _db.delete(_db.medicaments).go();
    await _db.delete(_db.specialites).go();
    await clearSourceMetadata();
    await resetSettingsMetadata();
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

  Future<List<Map<String, dynamic>>> getClusterSummaries({
    int limit = 40,
    int offset = 0,
    String? procedureType,
    String? formePharmaceutique,
  }) async {
    final filters = <String>["cluster_key != ''"];
    final args = <Variable>[];

    if (procedureType != null) {
      if (procedureType == 'Autorisation') {
        // WHY: Allopathie requires explicit autorisation matches.
        filters.add("procedure_type LIKE '%Autorisation%'");
      } else if (procedureType == 'Enregistrement') {
        // WHY: Homeopathy / Phytotherapy entries include either token in procedure type.
        filters.add(
          "(procedure_type LIKE '%homéo%' OR procedure_type LIKE '%phyto%')",
        );
      }
    }

    if (formePharmaceutique != null) {
      filters.add('forme_pharmaceutique = ?');
      args.add(Variable.withString(formePharmaceutique));
    }

    final whereClause = filters.join(' AND ');

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
          WHERE $whereClause
          GROUP BY cluster_key, princeps_brand_name
          ORDER BY princeps_brand_name COLLATE NOCASE
          LIMIT ? OFFSET ?
          ''',
          variables: [
            ...args,
            Variable.withInt(limit),
            Variable.withInt(offset),
          ],
          readsFrom: {_db.medicamentSummary},
        )
        .get();

    return rows
        .map(
          (row) => {
            'cluster_key': row.read<String>('cluster_key'),
            'princeps_brand_name': row.read<String>('princeps_brand_name'),
            'principes_payload': row.read<String>('principes_payload'),
            'group_count': row.read<int>('group_count'),
            'member_count': row.read<int>('member_count'),
          },
        )
        .toList();
  }

  Future<List<GenericGroupEntity>> getClusterGroupSummaries(
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
      final commonPrincipes = formatCommonPrincipes(commonPrincipesRaw);
      final princepsReference = row.read<String>('princeps_de_reference');
      final groupId = row.read<String>('group_id');

      return GenericGroupEntity(
        groupId: groupId,
        commonPrincipes: commonPrincipes,
        princepsReferenceName: princepsReference,
      );
    }).toList();
  }

  Future<List<GenericGroupEntity>> getGenericGroupSummaries({
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
    // WHY: Filter out standalone medications (group_id IS NULL) since this method
    // is specifically for generic group summaries which require a group.
    final groupIdFilter = whereClause.isEmpty
        ? 'WHERE group_id IS NOT NULL'
        : '$whereClause AND group_id IS NOT NULL';
    final query = _db.customSelect(
      '''
      SELECT DISTINCT
        principes_actifs_communs as common_principes,
        princeps_de_reference,
        group_id
      FROM medicament_summary
      $groupIdFilter
      ORDER BY princeps_de_reference COLLATE NOCASE
      LIMIT ? OFFSET ?
    ''',
      variables: [Variable.withInt(limit), Variable.withInt(offset)],
    );

    final results = await query.get();

    // Convert to GenericGroupSummary objects
    return results.map((row) {
      final commonPrincipesRaw = row.read<String>('common_principes');
      final commonPrincipes = formatCommonPrincipes(commonPrincipesRaw);
      final princepsReference = row.read<String>('princeps_de_reference');
      final groupId = row.read<String>('group_id');

      return GenericGroupEntity(
        groupId: groupId,
        commonPrincipes: commonPrincipes,
        princepsReferenceName: princepsReference,
      );
    }).toList();
  }

  Future<bool> hasExistingData() async {
    final totalGroupsQuery = _db.selectOnly(_db.generiqueGroups)
      ..addColumns([_db.generiqueGroups.groupId.count()]);
    final totalGroups = await totalGroupsQuery.getSingle();
    final count = totalGroups.read(_db.generiqueGroups.groupId.count()) ?? 0;

    return count > 0;
  }

  // WHY: Get distinct procedure types for filter dropdown
  Future<List<String>> getDistinctProcedureTypes() async {
    final query = _db.customSelect(
      '''
      SELECT DISTINCT procedure_type
      FROM medicament_summary
      WHERE procedure_type IS NOT NULL AND procedure_type != ''
      ORDER BY procedure_type
      ''',
      readsFrom: {_db.medicamentSummary},
    );
    final results = await query.get();
    return results.map((row) => row.read<String>('procedure_type')).toList();
  }

  // WHY: Get distinct pharmaceutical forms for filter dropdown
  Future<List<String>> getDistinctPharmaceuticalForms() async {
    final query = _db.customSelect(
      '''
      SELECT DISTINCT forme_pharmaceutique
      FROM medicament_summary
      WHERE forme_pharmaceutique IS NOT NULL AND forme_pharmaceutique != ''
      ORDER BY forme_pharmaceutique
      ''',
      readsFrom: {_db.medicamentSummary},
    );
    final results = await query.get();
    return results
        .map((row) => row.read<String>('forme_pharmaceutique'))
        .toList();
  }
}
