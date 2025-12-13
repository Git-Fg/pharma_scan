import 'package:drift/drift.dart';
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

}
