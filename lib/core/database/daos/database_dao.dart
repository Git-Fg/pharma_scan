// lib/core/database/daos/database_dao.dart
import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/daos/settings_dao.dart';
import 'package:pharma_scan/core/database/database.dart';

part 'database_dao.g.dart';

@DriftAccessor(
  tables: [
    Specialites,
    Medicaments,
    PrincipesActifs,
    GeneriqueGroups,
    GroupMembers,
    MedicamentSummary,
  ],
)
class DatabaseDao extends DatabaseAccessor<AppDatabase>
    with _$DatabaseDaoMixin {
  DatabaseDao(super.attachedDatabase);

  AppDatabase get database => attachedDatabase;

  Future<void> clearDatabase() async {
    await delete(medicamentSummary).go();
    await delete(groupMembers).go();
    await delete(generiqueGroups).go();
    await delete(principesActifs).go();
    await delete(medicaments).go();
    await delete(specialites).go();

    final settingsDao = SettingsDao(attachedDatabase);
    await settingsDao.clearSourceMetadata();
    await settingsDao.resetSettingsMetadata();
  }

  Future<void> insertBatchData({
    required List<Map<String, dynamic>> specialites,
    required List<Map<String, dynamic>> medicaments,
    required List<Map<String, dynamic>> principes,
    required List<Map<String, dynamic>> generiqueGroups,
    required List<Map<String, dynamic>> groupMembers,
  }) async {
    await batch((batch) {
      batch.insertAll(
        this.specialites,
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
            isSurveillance: Value(row['is_surveillance'] as bool? ?? false),
          ),
        ),
        mode: InsertMode.replace,
      );
      batch.insertAll(
        this.medicaments,
        medicaments.map(
          (row) => MedicamentsCompanion(
            codeCip: Value(row['code_cip'] as String),
            cisCode: Value(row['cis_code'] as String),
            presentationLabel: Value(row['presentation_label'] as String?),
            commercialisationStatut: Value(
              row['commercialisation_statut'] as String?,
            ),
            tauxRemboursement: Value(row['taux_remboursement'] as String?),
            prixPublic: Value(row['prix_public'] as double?),
          ),
        ),
        mode: InsertMode.replace,
      );
      batch.insertAll(
        principesActifs,
        principes.map(
          (row) => PrincipesActifsCompanion(
            codeCip: Value(row['code_cip'] as String),
            principe: Value(row['principe'] as String),
            dosage: Value(row['dosage'] as String?),
            dosageUnit: Value(row['dosage_unit'] as String?),
          ),
        ),
        mode: InsertMode.replace,
      );
      batch.insertAll(
        this.generiqueGroups,
        generiqueGroups.map(
          (row) => GeneriqueGroupsCompanion(
            groupId: Value(row['group_id'] as String),
            libelle: Value(row['libelle'] as String),
          ),
        ),
        mode: InsertMode.replace,
      );
      batch.insertAll(
        this.groupMembers,
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

  Future<int> populateSummaryTable() async {
    await database.transaction(() async {
      // Step 1: Clear existing summaries
      await database.deleteMedicamentSummaries();

      // Step 2: Insert grouped medications from view_aggregated_grouped
      await database.insertGroupedMedicamentSummaries();

      // Step 3: Insert standalone medications from view_aggregated_standalone
      await database.insertStandaloneMedicamentSummaries();
    });

    // Return count of inserted records
    // NOTE: getMedicamentSummaryCount already maps to int via .map() in generated code
    final result = await attachedDatabase
        .getMedicamentSummaryCount()
        .getSingle();
    return result;
  }

  Future<void> populateFts5Index() async {
    await database.deleteSearchIndex();
    await database.insertSearchIndexFromSummary();
  }
}
