// test/test_bootstrap.dart

/// WHY: Test utilities and helpers for database test setup.
/// Provides convenient access to SeedBuilder for fluent test data creation.
library;

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/database.dart';

export 'fixtures/seed_builder.dart';

List<SpecialitesCompanion> buildSpecialites(List<Map<String, dynamic>> rows) {
  return rows
      .map(
        (row) => SpecialitesCompanion(
          cisCode: Value(row['cis_code'] as String),
          nomSpecialite: Value(row['nom_specialite'] as String),
          procedureType: Value(
            row['procedure_type'] as String? ?? 'Autorisation',
          ),
          formePharmaceutique: Value(
            row['forme_pharmaceutique'] as String? ?? '',
          ),
          etatCommercialisation: Value(
            row['etat_commercialisation'] as String? ?? '',
          ),
          titulaireId: Value(row['titulaire_id'] as int?),
          conditionsPrescription: Value(
            row['conditions_prescription'] as String?,
          ),
          isSurveillance: Value(row['is_surveillance'] as bool? ?? false),
        ),
      )
      .toList();
}

List<MedicamentsCompanion> buildMedicaments(List<Map<String, dynamic>> rows) {
  return rows
      .map(
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
      )
      .toList();
}

List<PrincipesActifsCompanion> buildPrincipes(
  List<Map<String, dynamic>> rows,
) {
  return rows
      .map(
        (row) => PrincipesActifsCompanion(
          codeCip: Value(row['code_cip'] as String),
          principe: Value(row['principe'] as String),
          dosage: Value(row['dosage'] as String?),
          dosageUnit: Value(row['dosage_unit'] as String?),
        ),
      )
      .toList();
}

List<GeneriqueGroupsCompanion> buildGeneriqueGroups(
  List<Map<String, dynamic>> rows,
) {
  return rows
      .map(
        (row) => GeneriqueGroupsCompanion(
          groupId: Value(row['group_id'] as String),
          libelle: Value(row['libelle'] as String),
          princepsLabel: Value(row['princeps_label'] as String?),
          moleculeLabel: Value(row['molecule_label'] as String?),
          rawLabel: Value(
            row['raw_label'] as String? ?? row['libelle'] as String,
          ),
          parsingMethod: Value(
            row['parsing_method'] as String? ?? 'relational',
          ),
        ),
      )
      .toList();
}

List<GroupMembersCompanion> buildGroupMembers(
  List<Map<String, dynamic>> rows,
) {
  return rows
      .map(
        (row) => GroupMembersCompanion(
          codeCip: Value(row['code_cip'] as String),
          groupId: Value(row['group_id'] as String),
          type: Value(row['type'] as int),
        ),
      )
      .toList();
}
