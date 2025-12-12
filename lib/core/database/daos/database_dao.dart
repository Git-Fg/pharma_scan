import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:pharma_scan/core/database/daos/database_dao.drift.dart';
import 'package:pharma_scan/core/database/database.dart';

/// DAO pour les opérations générales sur la base de données.
///
/// Les données sont pré-remplies dans la DB téléchargée depuis GitHub.
/// Ce DAO contient uniquement les méthodes de lecture et de maintenance.
/// Les tables BDPM sont définies dans le schéma SQL et accessibles via customSelect/customUpdate.
@DriftAccessor()
class DatabaseDao extends DatabaseAccessor<AppDatabase> with $DatabaseDaoMixin {
  DatabaseDao(super.attachedDatabase);

  AppDatabase get database => attachedDatabase;

  /// Nettoie la base de données (uniquement pour les tests)
  @visibleForTesting
  Future<void> clearDatabase() async {
    await customUpdate('DELETE FROM medicament_summary', updates: {});
    await customUpdate('DELETE FROM group_members', updates: {});
    await customUpdate('DELETE FROM generique_groups', updates: {});
    await customUpdate('DELETE FROM principes_actifs', updates: {});
    await customUpdate('DELETE FROM medicaments', updates: {});
    await customUpdate('DELETE FROM specialites', updates: {});
    await customUpdate('DELETE FROM laboratories', updates: {});

    final settingsDao = SettingsDao(attachedDatabase);
    await settingsDao.clearSourceMetadata();
    await settingsDao.resetSettingsMetadata();
  }

  /// Inserts batch data into base tables using raw SQL (for testing only).
  /// Accepts Map format to avoid dependency on generated companion types.
  /// For new tests, prefer direct medicament_summary inserts (SQL-first).
  @visibleForTesting
  Future<void> insertBatchData({
    required Map<String, dynamic> batchData,
  }) async {
    final specialitesList =
        batchData['specialites'] as List<Map<String, dynamic>>? ?? [];
    final medicamentsList =
        batchData['medicaments'] as List<Map<String, dynamic>>? ?? [];
    final principesList =
        batchData['principes'] as List<Map<String, dynamic>>? ?? [];
    final generiqueGroupsList =
        batchData['generiqueGroups'] as List<Map<String, dynamic>>? ?? [];
    final groupMembersList =
        batchData['groupMembers'] as List<Map<String, dynamic>>? ?? [];
    final laboratoriesList =
        batchData['laboratories'] as List<Map<String, dynamic>>? ?? [];

    // Insert laboratories first
    for (final lab in laboratoriesList) {
      await customInsert(
        'INSERT OR REPLACE INTO laboratories (id, name) VALUES (?, ?)',
        variables: [
          Variable.withInt(lab['id'] as int),
          Variable.withString(lab['name'] as String),
        ],
        updates: {attachedDatabase.laboratories},
      );
    }

    // Insert specialites
    for (final specialite in specialitesList) {
      await customInsert(
        '''
        INSERT OR REPLACE INTO specialites (
          cis_code, nom_specialite, procedure_type, forme_pharmaceutique,
          voies_administration, titulaire_id, conditions_prescription,
          is_surveillance, statut_administratif, etat_commercialisation
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        variables: [
          Variable.withString(specialite['cisCode'] as String),
          Variable.withString(specialite['nomSpecialite'] as String),
          Variable.withString(
            specialite['procedureType'] as String? ?? 'Autorisation',
          ),
          Variable.withString(
            specialite['formePharmaceutique'] as String? ?? '',
          ),
          Variable.withString(
            specialite['voiesAdministration'] as String? ?? '',
          ),
          Variable.withInt(specialite['titulaireId'] as int? ?? 0),
          Variable.withString(
            specialite['conditionsPrescription'] as String? ?? '',
          ),
          Variable.withBool(specialite['isSurveillance'] as bool? ?? false),
          Variable.withString(
            specialite['statutAdministratif'] as String? ?? '',
          ),
          Variable.withString(
            specialite['etatCommercialisation'] as String? ?? '',
          ),
        ],
        updates: {attachedDatabase.specialites},
      );
    }

    // Insert medicaments
    for (final medicament in medicamentsList) {
      await customInsert(
        '''
        INSERT OR REPLACE INTO medicaments (
          code_cip, cis_code, presentation_label, commercialisation_statut,
          taux_remboursement, prix_public
        ) VALUES (?, ?, ?, ?, ?, ?)
        ''',
        variables: [
          Variable.withString(medicament['codeCip'] as String),
          Variable.withString(medicament['cisCode'] as String),
          Variable.withString(medicament['presentationLabel'] as String? ?? ''),
          Variable.withString(
            medicament['commercialisationStatut'] as String? ?? '',
          ),
          Variable.withString(medicament['tauxRemboursement'] as String? ?? ''),
          Variable.withReal(medicament['prixPublic'] as double? ?? 0.0),
        ],
        updates: {attachedDatabase.medicaments},
      );
    }

    // Insert principes_actifs
    for (final principe in principesList) {
      await customInsert(
        '''
        INSERT INTO principes_actifs (
          code_cip, principe, dosage, dosage_unit, principe_normalized
        ) VALUES (?, ?, ?, ?, ?)
        ''',
        variables: [
          Variable.withString(principe['codeCip'] as String),
          Variable.withString(principe['principe'] as String),
          Variable.withString(principe['dosage'] as String? ?? ''),
          Variable.withString(principe['dosageUnit'] as String? ?? ''),
          Variable.withString(principe['principeNormalized'] as String? ?? ''),
        ],
        updates: {attachedDatabase.principesActifs},
      );
    }

    // Insert generique_groups
    for (final group in generiqueGroupsList) {
      await customInsert(
        '''
        INSERT OR REPLACE INTO generique_groups (
          group_id, libelle, raw_label, parsing_method,
          princeps_label, molecule_label
        ) VALUES (?, ?, ?, ?, ?, ?)
        ''',
        variables: [
          Variable.withString(group['groupId'] as String),
          Variable.withString(group['libelle'] as String),
          Variable.withString(
            group['rawLabel'] as String? ?? group['libelle'] as String,
          ),
          Variable.withString(
            group['parsingMethod'] as String? ?? 'relational',
          ),
          Variable.withString(group['princepsLabel'] as String? ?? ''),
          Variable.withString(group['moleculeLabel'] as String? ?? ''),
        ],
        updates: {attachedDatabase.generiqueGroups},
      );
    }

    // Insert group_members
    for (final member in groupMembersList) {
      await customInsert(
        '''
        INSERT OR REPLACE INTO group_members (
          code_cip, group_id, type, sort_order
        ) VALUES (?, ?, ?, ?)
        ''',
        variables: [
          Variable.withString(member['codeCip'] as String),
          Variable.withString(member['groupId'] as String),
          Variable.withInt(member['type'] as int),
          Variable.withInt(member['sortOrder'] as int? ?? 0),
        ],
        updates: {attachedDatabase.groupMembers},
      );
    }
  }

  
  /// Populates FTS5 search_index from medicament_summary (for testing only).
  @visibleForTesting
  Future<void> populateFts5Index() async {
    await customUpdate('DELETE FROM search_index', updates: {});

    await customUpdate(
      '''
      INSERT INTO search_index (cis_code, molecule_name, brand_name)
      SELECT
        cis_code,
        nom_canonique,
        princeps_brand_name
      FROM medicament_summary
      ''',
      updates: {},
    );
  }
}
