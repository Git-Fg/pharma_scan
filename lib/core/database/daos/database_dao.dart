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
    // Settings are now managed by PreferencesService (SharedPreferences)
  }
}
