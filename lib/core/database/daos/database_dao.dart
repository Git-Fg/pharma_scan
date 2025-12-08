import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/daos/settings_dao.dart';
import 'package:pharma_scan/core/database/database.dart';

part 'database_dao.g.dart';

class IngestionBatch {
  const IngestionBatch({
    required this.specialites,
    required this.medicaments,
    required this.principes,
    required this.generiqueGroups,
    required this.groupMembers,
    required this.laboratories,
    this.availability = const [],
  });

  final List<SpecialitesCompanion> specialites;
  final List<MedicamentsCompanion> medicaments;
  final List<PrincipesActifsCompanion> principes;
  final List<GeneriqueGroupsCompanion> generiqueGroups;
  final List<GroupMembersCompanion> groupMembers;
  final List<LaboratoriesCompanion> laboratories;
  final List<MedicamentAvailabilityCompanion> availability;
}

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
    await delete(laboratories).go();

    final settingsDao = SettingsDao(attachedDatabase);
    await settingsDao.clearSourceMetadata();
    await settingsDao.resetSettingsMetadata();
  }

  Future<void> insertBatchData({required IngestionBatch batchData}) async {
    await database.transaction(() async {
      try {
        await batch((batch) {
          batch
            ..insertAll(
              laboratories,
              batchData.laboratories,
              mode: InsertMode.replace,
            )
            ..insertAll(
              specialites,
              batchData.specialites,
              mode: InsertMode.replace,
            )
            ..insertAll(
              medicaments,
              batchData.medicaments,
              mode: InsertMode.replace,
            )
            ..insertAll(
              principesActifs,
              batchData.principes,
              mode: InsertMode.replace,
            )
            ..insertAll(
              generiqueGroups,
              batchData.generiqueGroups,
              mode: InsertMode.replace,
            )
            ..insertAll(
              groupMembers,
              batchData.groupMembers,
              mode: InsertMode.replace,
            );
        });

        await database.batch((batch) {
          batch.deleteWhere<MedicamentAvailability, MedicamentAvailabilityData>(
            database.medicamentAvailability,
            (_) => const Constant(true),
          );
        });

        if (batchData.availability.isNotEmpty) {
          await database.batch((batch) {
            batch.insertAll(
              database.medicamentAvailability,
              batchData.availability,
              mode: InsertMode.replace,
            );
          });
        }
      } finally {}
    });
  }

  Future<int> populateSummaryTable() async {
    await database.transaction(() async {
      await database.deleteMedicamentSummaries();
      await database.insertGroupedMedicamentSummaries();
      await database.insertStandaloneMedicamentSummaries();
    });

    final result = await attachedDatabase
        .getMedicamentSummaryCount()
        .getSingle();
    return result;
  }

  Future<void> populateFts5Index() async {
    await database.deleteSearchIndex();
    await database.insertSearchIndexFromSummary();
  }

  /// Cross-validates and refines group metadata by verifying parsed princepsLabel
  /// against actual Type 0 (princeps) member names.
  ///
  /// This is called during data ingestion to ensure princepsLabel matches actual
  /// Type 0 member names. If no match is found, uses the shortest princeps name as fallback.
  Future<void> refineGroupMetadata() async {
    await attachedDatabase.refineGroupMetadata();
  }
}
