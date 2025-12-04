import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/daos/settings_dao.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';

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
      batch
        ..insertAll(
          this.specialites,
          specialites.map(
            (row) => SpecialitesCompanion(
              cisCode: Value(row['cis_code'] as String),
              nomSpecialite: Value(row['nom_specialite'] as String),
              procedureType: Value(row['procedure_type'] as String),
              formePharmaceutique: Value(
                row['forme_pharmaceutique'] as String?,
              ),
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
        )
        ..insertAll(
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
        )
        ..insertAll(
          principesActifs,
          principes.map(
            (row) {
              final principe = row['principe'] as String;
              return PrincipesActifsCompanion(
                codeCip: Value(row['code_cip'] as String),
                principe: Value(principe),
                principeNormalized: Value(
                  principe.isNotEmpty
                      ? normalizePrincipleOptimal(principe)
                      : null,
                ),
                dosage: Value(row['dosage'] as String?),
                dosageUnit: Value(row['dosage_unit'] as String?),
              );
            },
          ),
          mode: InsertMode.replace,
        )
        ..insertAll(
          this.generiqueGroups,
          generiqueGroups.map(
            (row) => GeneriqueGroupsCompanion(
              groupId: Value(row['group_id'] as String),
              libelle: Value(row['libelle'] as String),
              princepsLabel: Value(row['princeps_label'] as String?),
              moleculeLabel: Value(row['molecule_label'] as String?),
            ),
          ),
          mode: InsertMode.replace,
        )
        ..insertAll(
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
    final groups = await select(generiqueGroups).get();

    for (final group in groups) {
      if (group.groupId.isEmpty) continue;

      var extractedMoleculeLabel = group.moleculeLabel;
      if (extractedMoleculeLabel == null || extractedMoleculeLabel.isEmpty) {
        final libelle = group.libelle;
        if (libelle.isNotEmpty) {
          var cleaned = libelle
              .replaceAll(RegExp(r'\s*\([^)]+\)\s*$'), '')
              .trim();
          const saltSuffixes = [
            'ARGININE',
            'TOSILATE',
            'TERT-BUTYLAMINE',
            'TERT BUTYLAMINE',
            'TERTBUTYLAMINE',
          ];
          for (final suffix in saltSuffixes) {
            final suffixPattern = RegExp(
              r'\s+' + RegExp.escape(suffix) + r'(?:\s|$)',
              caseSensitive: false,
            );
            cleaned = cleaned.replaceAll(suffixPattern, ' ').trim();
          }
          extractedMoleculeLabel = cleaned.isEmpty ? null : cleaned;
        }
      }

      final princepsMembers =
          await (select(groupMembers)
                ..where((gm) => gm.groupId.equals(group.groupId))
                ..where((gm) => gm.type.equals(0)))
              .join([
                innerJoin(
                  medicaments,
                  medicaments.codeCip.equalsExp(groupMembers.codeCip),
                ),
                innerJoin(
                  specialites,
                  specialites.cisCode.equalsExp(medicaments.cisCode),
                ),
              ])
              .get();

      final parsedLabel = group.princepsLabel;
      String? confirmedLabel;

      if (parsedLabel != null && parsedLabel.isNotEmpty) {
        confirmedLabel = parsedLabel;
      } else if (princepsMembers.isNotEmpty) {
        final princepsNames = princepsMembers
            .map((row) => row.readTable(specialites).nomSpecialite)
            .where((name) => name.isNotEmpty)
            .toList();

        if (princepsNames.isNotEmpty) {
          // Use shortest name as fallback (heuristic: shortest is often the brand name)
          confirmedLabel = princepsNames.reduce(
            (a, b) => a.length <= b.length ? a : b,
          );
        }
      }

      final needsPrincepsUpdate =
          confirmedLabel != null && confirmedLabel != group.princepsLabel;
      final needsMoleculeUpdate = extractedMoleculeLabel != group.moleculeLabel;

      if (needsPrincepsUpdate || needsMoleculeUpdate) {
        await (update(
          generiqueGroups,
        )..where((gg) => gg.groupId.equals(group.groupId))).write(
          GeneriqueGroupsCompanion(
            princepsLabel: needsPrincepsUpdate
                ? Value(confirmedLabel)
                : const Value.absent(),
            moleculeLabel: needsMoleculeUpdate
                ? Value(extractedMoleculeLabel)
                : const Value.absent(),
          ),
        );
      }
    }
  }
}
