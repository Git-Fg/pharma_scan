// lib/core/services/database_service.dart
import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart' hide Medicament;
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';
import 'package:pharma_scan/core/utils/string_normalizer.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_summary_model.dart';
import 'package:pharma_scan/features/explorer/models/group_details_model.dart';
import 'package:pharma_scan/features/explorer/models/grouped_by_laboratory_model.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';

class DatabaseService {
  final AppDatabase _db = sl<AppDatabase>();

  // WHY: Unified method to handle both generic and princeps scans.
  // This method identifies the type of medicament and returns the appropriate result.
  Future<ScanResult?> getScanResultByCip(String codeCip) async {
    final groupMemberQuery = _db.select(_db.groupMembers)
      ..where((tbl) => tbl.codeCip.equals(codeCip));
    final memberInfo = await groupMemberQuery.getSingleOrNull();

    if (memberInfo == null) return null;

    final allGroupMembersQuery = _db.select(_db.specialites).join([
      innerJoin(
        _db.medicaments,
        _db.medicaments.cisCode.equalsExp(_db.specialites.cisCode),
      ),
      innerJoin(
        _db.groupMembers,
        _db.groupMembers.codeCip.equalsExp(_db.medicaments.codeCip),
      ),
    ])..where(_db.groupMembers.groupId.equals(memberInfo.groupId));

    final groupMembers = await allGroupMembersQuery.get();

    final scannedMedicamentRow = groupMembers.firstWhere(
      (row) => row.readTable(_db.medicaments).codeCip == codeCip,
    );
    final scannedMedicamentData = scannedMedicamentRow.readTable(
      _db.specialites,
    );
    final scannedMedicamentCip = scannedMedicamentRow
        .readTable(_db.medicaments)
        .codeCip;

    final principesQuery = _db.select(_db.principesActifs)
      ..where((tbl) => tbl.codeCip.equals(codeCip));
    final principesData = await principesQuery.get();
    final principes = principesData.map((row) => row.principe).toList();

    // WHY: On récupère le premier dosage pour le médicament scanné (le plus représentatif)
    final firstPrincipeData = principesData.isNotEmpty
        ? principesData.first
        : null;

    final scannedMedicament = Medicament(
      nom: scannedMedicamentData.nomSpecialite,
      codeCip: scannedMedicamentCip,
      principesActifs: principes,
      titulaire: scannedMedicamentData.titulaire,
      formePharmaceutique: scannedMedicamentData.formePharmaceutique,
      dosage: firstPrincipeData?.dosage,
      dosageUnit: firstPrincipeData?.dosageUnit,
    );

    if (memberInfo.type == 1) {
      // Scanned a GENERIC
      final associatedPrinceps = groupMembers
          .where((row) => row.readTable(_db.groupMembers).type == 0)
          .map((row) {
            final medData = row.readTable(_db.medicaments);
            final specData = row.readTable(_db.specialites);
            return Medicament(
              nom: specData.nomSpecialite,
              codeCip: medData.codeCip,
              principesActifs: [],
            );
          })
          .toList();

      return ScanResult.generic(
        medicament: scannedMedicament,
        associatedPrinceps: associatedPrinceps,
        groupId: memberInfo.groupId,
      );
    } else {
      // Scanned a PRINCEPS
      final genericLabs = groupMembers
          .where((row) => row.readTable(_db.groupMembers).type == 1)
          .map((row) => row.readTable(_db.specialites).titulaire)
          .where((titulaire) => titulaire != null && titulaire.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      return ScanResult.princeps(
        princeps: scannedMedicament,
        moleculeName: principes.isNotEmpty ? principes.first : 'N/A',
        genericLabs: genericLabs,
        groupId: memberInfo.groupId,
      );
    }
  }

  Future<GroupDetails> getGroupDetails(
    String groupId, {
    bool showAll = false,
  }) async {
    // --- PARTIE 1: Récupérer les membres du groupe actuel ---
    final allGroupMembersQuery = _db.select(_db.specialites).join([
      innerJoin(
        _db.medicaments,
        _db.medicaments.cisCode.equalsExp(_db.specialites.cisCode),
      ),
      innerJoin(
        _db.groupMembers,
        _db.groupMembers.codeCip.equalsExp(_db.medicaments.codeCip),
      ),
    ])..where(_db.groupMembers.groupId.equals(groupId));

    final groupMembers = await allGroupMembersQuery.get();

    final List<Medicament> princepsList = [];
    final List<Medicament> allGenerics = [];

    for (final row in groupMembers) {
      final medData = row.readTable(_db.medicaments);
      final specData = row.readTable(_db.specialites);
      final memberData = row.readTable(_db.groupMembers);

      final principesQuery = _db.select(_db.principesActifs)
        ..where((tbl) => tbl.codeCip.equals(medData.codeCip));
      final principesData = await principesQuery.get();
      final firstPrincipeData = principesData.isNotEmpty
          ? principesData.first
          : null;

      final medicament = Medicament(
        nom: specData.nomSpecialite,
        codeCip: medData.codeCip,
        principesActifs: principesData.map((p) => p.principe).toList(),
        dosage: firstPrincipeData?.dosage,
        dosageUnit: firstPrincipeData?.dosageUnit,
        titulaire: specData.titulaire,
      );

      if (memberData.type == 0) {
        princepsList.add(medicament);
      } else {
        allGenerics.add(medicament);
      }
    }

    // WHY: Group generics by laboratory for a more intuitive UI.
    // This groups products by their manufacturer, which is more useful for professionals.
    final Map<String, List<Medicament>> genericsByLab = {};
    for (final generic in allGenerics) {
      final lab = generic.titulaire ?? 'Laboratoire Inconnu';
      genericsByLab.putIfAbsent(lab, () => []).add(generic);
    }

    final groupedGenericsList = genericsByLab.entries.map((entry) {
      // Sort products within the group by name for consistency
      final sortedProducts = List<Medicament>.from(entry.value);
      sortedProducts.sort((a, b) => a.nom.compareTo(b.nom));
      return GroupedByLaboratory(
        laboratory: entry.key,
        products: sortedProducts,
      );
    }).toList();

    // --- PARTIE 2: Trouver les principes actifs communs du groupe ---
    final commonPrincipesQuery = _db.customSelect(
      '''
      SELECT DISTINCT pa.principe
      FROM group_members gm
      JOIN principes_actifs pa ON gm.code_cip = pa.code_cip
      WHERE gm.group_id = ? AND pa.principe IS NOT NULL
      ''',
      variables: [Variable.withString(groupId)],
    );
    final commonPrincipesResult = await commonPrincipesQuery.get();
    final commonPrincipes = commonPrincipesResult
        .map((row) => row.read<String>('principe'))
        .toList();

    // --- PARTIE 3: Trouver les princeps associés dans d'autres groupes ---
    List<Medicament> relatedPrincepsList = [];
    if (commonPrincipes.isNotEmpty) {
      final relatedPrincepsQuery =
          _db.select(_db.specialites).join([
              innerJoin(
                _db.medicaments,
                _db.medicaments.cisCode.equalsExp(_db.specialites.cisCode),
              ),
              innerJoin(
                _db.groupMembers,
                _db.groupMembers.codeCip.equalsExp(_db.medicaments.codeCip),
              ),
              innerJoin(
                _db.principesActifs,
                _db.principesActifs.codeCip.equalsExp(_db.medicaments.codeCip),
              ),
            ])
            ..where(_db.groupMembers.type.equals(0)) // Doit être un princeps
            ..where(
              _db.groupMembers.groupId.equals(groupId).not(),
            ) // Ne doit PAS être dans le groupe actuel
            ..where(
              _db.principesActifs.principe.isIn(commonPrincipes),
            ); // Doit partager le principe actif

      final relatedPrincepsRows = await relatedPrincepsQuery.get();

      // WHY: Collect unique CIP codes and preserve row data for efficient batch processing.
      // This eliminates the N+1 query problem by fetching all principes actifs in a single query.
      final uniquePrincepsMap = <String, TypedResult>{
        for (final row in relatedPrincepsRows)
          row.readTable(_db.medicaments).codeCip: row,
      };
      final uniqueCips = uniquePrincepsMap.keys.toList();

      Map<String, List<String>> principesByCip = {};
      if (uniqueCips.isNotEmpty) {
        // WHY: Batch query to fetch all principes actifs for all unique CIPs at once.
        final allPrincipesQuery = _db.select(_db.principesActifs)
          ..where((tbl) => tbl.codeCip.isIn(uniqueCips));
        final allPrincipesData = await allPrincipesQuery.get();

        for (final pa in allPrincipesData) {
          principesByCip.putIfAbsent(pa.codeCip, () => []).add(pa.principe);
        }
      }

      // WHY: Reconstruct Medicament objects using pre-fetched data from the join and batch query.
      for (final cip in uniqueCips) {
        final row = uniquePrincepsMap[cip]!;
        final specData = row.readTable(_db.specialites);
        final principeData = row.readTable(_db.principesActifs);

        relatedPrincepsList.add(
          Medicament(
            nom: specData.nomSpecialite,
            codeCip: cip,
            principesActifs: principesByCip[cip] ?? [],
            dosage: principeData.dosage,
            dosageUnit: principeData.dosageUnit,
            titulaire: specData.titulaire,
          ),
        );
      }
    }

    return GroupDetails(
      princeps: princepsList,
      generics: groupedGenericsList,
      relatedPrinceps: relatedPrincepsList,
    );
  }

  // TODO: Remove database clearing on schema change once app is ready for production. Implement proper migration logic instead.
  Future<void> clearDatabase() async {
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
          ),
        ),
        mode: InsertMode.replace,
      );
      batch.insertAll(
        _db.medicaments,
        medicaments.map(
          (row) => MedicamentsCompanion(
            codeCip: Value(row['code_cip'] as String),
            nom: Value(row['nom'] as String),
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
            dosage: Value(row['dosage'] as double?),
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

  Future<List<GenericGroupSummary>> getGenericGroupSummaries({
    List<String>? formKeywords,
    List<String>? excludeKeywords,
    int limit = 100,
    int offset = 0,
  }) async {
    // WHY: Default to oral forms as they are the most common use case.
    final defaultOralKeywords = [
      'comprimé',
      'gélule',
      'capsule',
      'lyophilisat',
      'solution buvable',
      'sirop',
      'suspension buvable',
      'comprimé orodispersible',
    ];
    final defaultExcludeKeywords = [
      'injectable',
      'injection',
      'vaginal',
      'vaginale',
    ];
    final keywordsToUse = formKeywords ?? defaultOralKeywords;
    final excludesToUse = excludeKeywords ?? defaultExcludeKeywords;

    // Special case: if formKeywords is empty, we want groups where NO form matches excludeKeywords
    // This is used for the "other" category
    final String whereClause;
    if (keywordsToUse.isEmpty && excludesToUse.isNotEmpty) {
      // For "other" category: find groups where no form matches any exclude keyword
      whereClause =
          '''
        WHERE NOT EXISTS (
          SELECT 1
          FROM group_members gm_exclude
          INNER JOIN medicaments m_exclude ON gm_exclude.code_cip = m_exclude.code_cip
          INNER JOIN specialites s_exclude ON m_exclude.cis_code = s_exclude.cis_code
          WHERE gm_exclude.group_id = gg.group_id
            AND (${excludesToUse.map((kw) => "s_exclude.forme_pharmaceutique LIKE '%${kw.replaceAll("'", "''")}%'").join(' OR ')})
        )
      ''';
    } else {
      // Normal case: find groups where at least one form matches keywords and doesn't match excludes
      final formConditions = keywordsToUse
          .map(
            (kw) =>
                "s2.forme_pharmaceutique LIKE '%${kw.replaceAll("'", "''")}%'",
          )
          .join(' OR ');

      final excludeConditions = excludesToUse.isEmpty
          ? ''
          : ' AND ${excludesToUse.map((kw) => "s2.forme_pharmaceutique NOT LIKE '%${kw.replaceAll("'", "''")}%'").join(' AND ')}';

      whereClause =
          '''
        WHERE EXISTS (
          SELECT 1
          FROM group_members gm2
          INNER JOIN medicaments m2 ON gm2.code_cip = m2.code_cip
          INNER JOIN specialites s2 ON m2.cis_code = s2.cis_code
          WHERE gm2.group_id = gg.group_id AND ($formConditions) $excludeConditions
        )
      ''';
    }

    // WHY: Phase 1 - Fetch only distinct group labels matching the filter.
    // This is a much smaller dataset than fetching all princeps names.
    // We fetch group_id and libelle only, which allows us to normalize and group efficiently.
    final groupLabelsQuery = _db.customSelect(
      '''
      SELECT DISTINCT
        gg.group_id,
        gg.libelle
      FROM generique_groups gg
      $whereClause
      ''',
      readsFrom: {_db.generiqueGroups},
    );

    final groupLabelsResults = await groupLabelsQuery.get();

    // WHY: Phase 2 - Normalize, group, and sort in Dart to get unique normalized labels.
    // This processing is fast and allows us to determine which groups belong to each normalized label.
    final groupsByPrinciple = <String, Map<String, dynamic>>{};
    for (final row in groupLabelsResults) {
      final groupLabel = row.read<String>('libelle');
      final cleanedLabel = cleanGroupLabel(groupLabel);
      final normalizedLabel = normalize(cleanedLabel);

      if (normalizedLabel.isEmpty) continue;

      final groupId = row.read<String>('group_id');

      groupsByPrinciple.putIfAbsent(
        normalizedLabel,
        () => {'displayLabel': cleanedLabel, 'groupIds': <String>{}},
      );

      groupsByPrinciple[normalizedLabel]!['groupIds'].add(groupId);
    }

    // Create intermediate summaries with normalized labels for sorting
    final intermediateSummaries = groupsByPrinciple.entries.map((entry) {
      final displayLabel = entry.value['displayLabel'] as String;
      final groupIds = (entry.value['groupIds'] as Set<String>).toList();

      return {
        'normalizedLabel': entry.key,
        'displayLabel': displayLabel,
        'groupIds': groupIds,
      };
    }).toList();

    // Sort by display label (alphabetically by active principle)
    intermediateSummaries.sort(
      (a, b) =>
          (a['displayLabel'] as String).compareTo(b['displayLabel'] as String),
    );

    // WHY: Phase 3 - Apply pagination on the sorted unique labels.
    // This ensures we only process the groups needed for the current page.
    if (offset >= intermediateSummaries.length) return [];
    final end = (offset + limit > intermediateSummaries.length)
        ? intermediateSummaries.length
        : offset + limit;
    final paginatedSummaries = intermediateSummaries.sublist(offset, end);

    // WHY: Phase 4 - Fetch princeps names only for the paginated groups.
    // This dramatically reduces memory usage by fetching princeps data only for the current page.
    final paginatedGroupIds = <String>{};
    for (final summary in paginatedSummaries) {
      paginatedGroupIds.addAll((summary['groupIds'] as List<String>));
    }

    if (paginatedGroupIds.isEmpty) return [];

    final placeholders = List.generate(
      paginatedGroupIds.length,
      (_) => '?',
    ).join(',');
    final princepsQuery = _db.customSelect(
      '''
      SELECT
        gm.group_id,
        s.nom_specialite as princeps_name
      FROM group_members gm
      INNER JOIN medicaments m ON gm.code_cip = m.code_cip
      INNER JOIN specialites s ON m.cis_code = s.cis_code
      WHERE gm.group_id IN ($placeholders) AND gm.type = 0
      ''',
      readsFrom: {_db.groupMembers, _db.medicaments, _db.specialites},
      variables: paginatedGroupIds
          .map((id) => Variable.withString(id))
          .toList(),
    );

    final princepsResults = await princepsQuery.get();

    // Map princeps names to group IDs
    final princepsByGroupId = <String, Set<String>>{};
    for (final row in princepsResults) {
      final groupId = row.read<String>('group_id');
      final princepsName = row.read<String?>('princeps_name');
      if (princepsName != null) {
        princepsByGroupId
            .putIfAbsent(groupId, () => <String>{})
            .add(princepsName);
      }
    }

    // Build final summaries with princeps names
    final summaries = <GenericGroupSummary>[];
    for (final summary in paginatedSummaries) {
      final displayLabel = summary['displayLabel'] as String;
      final groupIds = summary['groupIds'] as List<String>;
      final representativeGroupId = groupIds.first;

      // Collect all princeps names from all groups in this normalized label
      final allPrincepsNames = <String>{};
      for (final groupId in groupIds) {
        final princepsNames = princepsByGroupId[groupId];
        if (princepsNames != null) {
          allPrincepsNames.addAll(princepsNames);
        }
      }

      summaries.add(
        GenericGroupSummary(
          groupId: representativeGroupId,
          commonPrincipes: displayLabel,
          princepsReferenceName: findCommonPrincepsName(
            allPrincepsNames.toList(),
          ),
        ),
      );
    }

    return summaries;
  }

  // WHY: Search now includes active ingredients for a more powerful discovery experience.
  // It joins with principes_actifs and uses groupBy to return distinct medications.
  // Conditionally applies a relevance filter to exclude homeopathic and phytotherapy products.
  Future<List<Medicament>> searchMedicaments(
    String query, {
    bool showAll = false,
  }) async {
    final sanitizedQuery = '%${query.toLowerCase()}%';

    final queryBuilder = _db.select(_db.medicaments).join([
      innerJoin(
        _db.specialites,
        _db.specialites.cisCode.equalsExp(_db.medicaments.cisCode),
      ),
      // Use a left join as not all medications might have listed principles
      leftOuterJoin(
        _db.principesActifs,
        _db.principesActifs.codeCip.equalsExp(_db.medicaments.codeCip),
      ),
    ]);

    // Apply the search condition
    queryBuilder.where(
      _db.specialites.nomSpecialite.lower().like(sanitizedQuery) |
          _db.medicaments.codeCip.like(sanitizedQuery) |
          _db.principesActifs.principe.lower().like(sanitizedQuery),
    );

    // Conditionally apply the relevance filter
    if (!showAll) {
      queryBuilder.where(
        _db.specialites.procedureType.lower().like('%homéo%').not() &
            _db.specialites.procedureType.lower().like('%phyto%').not(),
      );
    }

    queryBuilder
      ..groupBy([_db.medicaments.codeCip])
      ..limit(50);

    final results = await queryBuilder.get();

    // WHY: For list display, we don't load principes actifs to improve performance.
    // They will be loaded on detail view via getScanResultByCip.
    // We use the clean name from specialites table instead of the packaging description.
    return results.map((row) {
      final medData = row.readTable(_db.medicaments);
      final specData = row.readTable(_db.specialites);
      return Medicament(
        nom: specData.nomSpecialite,
        codeCip: medData.codeCip,
        principesActifs: [],
      );
    }).toList();
  }
}
