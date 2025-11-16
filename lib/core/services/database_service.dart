// lib/core/services/database_service.dart
import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart' hide Medicament;
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_summary_model.dart';
import 'package:pharma_scan/features/explorer/models/group_details_model.dart';
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
    final List<Medicament> genericsList = [];

    for (final row in groupMembers) {
      final medData = row.readTable(_db.medicaments);
      final specData = row.readTable(_db.specialites);
      final memberData = row.readTable(_db.groupMembers);

      final medicament = Medicament(
        nom: specData.nomSpecialite,
        codeCip: medData.codeCip,
        principesActifs: [],
      );

      if (memberData.type == 0) {
        princepsList.add(medicament);
      } else {
        genericsList.add(medicament);
      }
    }
    return GroupDetails(princeps: princepsList, generics: genericsList);
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
    int limit = 100,
  }) async {
    // WHY: Cette requête est refactorisée pour être la source de vérité des groupes.
    // 1. Elle identifie les principes actifs communs à un groupe en joignant jusqu'à la table `principes_actifs`.
    // 2. Elle utilise `GROUP_CONCAT(DISTINCT pa.principe)` pour créer une liste propre des principes, éliminant le besoin de parser le `libelle`.
    // 3. Elle continue de lister les princeps de référence pour la deuxième colonne de l'UI.
    // WHY: SQLite ne supporte pas GROUP_CONCAT(DISTINCT column, separator).
    // On utilise une sous-requête pour obtenir les principes distincts, puis on les concatène avec ' + '.
    final query = _db.customSelect(
      '''
      SELECT
        gg.group_id,
        (
          SELECT GROUP_CONCAT(principe, ' + ')
          FROM (
            SELECT DISTINCT pa.principe
            FROM group_members gm2
            LEFT JOIN principes_actifs pa ON gm2.code_cip = pa.code_cip
            WHERE gm2.group_id = gg.group_id AND pa.principe IS NOT NULL
            ORDER BY pa.principe
          )
        ) as common_principes,
        GROUP_CONCAT(DISTINCT princeps_spec.nom_specialite) as princeps_names
      FROM generique_groups gg
      LEFT JOIN group_members princeps_gm ON gg.group_id = princeps_gm.group_id AND princeps_gm.type = 0
      LEFT JOIN medicaments princeps_m ON princeps_gm.code_cip = princeps_m.code_cip
      LEFT JOIN specialites princeps_spec ON princeps_m.cis_code = princeps_spec.cis_code
      GROUP BY gg.group_id
      ORDER BY common_principes
      LIMIT ?
      ''',
      variables: [Variable.withInt(limit)],
    );

    final results = await query.get();
    return results.map((row) {
      final princepsNames = row.read<String?>('princeps_names');
      final commonPrincipes = row.read<String?>('common_principes');
      return GenericGroupSummary(
        // On utilise les principes actifs comme label principal.
        // Le séparateur ' + ' est utilisé pour une meilleure lisibilité.
        commonPrincipes: commonPrincipes ?? 'Principe non spécifié',
        princepsNames: princepsNames?.split(',') ?? [],
      );
    }).toList();
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
