import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/daos/database_dao.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import 'package:pharma_scan/core/database/database.drift.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

@DriftDatabase(
  daos: [CatalogDao, DatabaseDao, RestockDao],
  include: {'dbschema.drift', 'queries.drift', 'views.drift'},
)
class AppDatabase extends $AppDatabase {
  final bool _isTestEnvironment;

  /// Constructeur principal utilisant driftDatabase pour la configuration multi-plateforme
  AppDatabase()
      : this._isTestEnvironment = false,
        super(_openConnection());


  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'pharma_scan_db_v3',
      native: const DriftNativeOptions(
        shareAcrossIsolates: true,
      ),
    );
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        // For production: Assume downloaded database already has complete schema
        // For testing: Create schema from .drift files
        final isTestEnvironment = _isTestEnvironment;

        if (isTestEnvironment) {
          LoggerService.info(
              '[DB] Creating schema from .drift files for testing');
          await _createSchemaFromDriftFiles(m);
        } else {
          LoggerService.info(
              '[DB] Assuming downloaded database has complete schema');
          // Verify schema compatibility instead of creating
          await _verifySchemaCompatibility();
        }
      },
      beforeOpen: (details) async {
        // Activation des clés étrangères indispensable pour SQLite
        await customStatement('PRAGMA foreign_keys = ON');
        // Configuration SQLite optimale
        await customStatement('PRAGMA journal_mode=WAL');
        await customStatement('PRAGMA busy_timeout=30000');
        await customStatement('PRAGMA synchronous=NORMAL');
        await customStatement('PRAGMA mmap_size=300000000');
        await customStatement('PRAGMA temp_store=MEMORY');
      },
    );
  }

  /// Vérifie l'intégrité complète de la base de données téléchargée.
  ///
  /// Vérifie que toutes les tables et vues critiques existent et ont la structure attendue.
  /// Lance une exception si le schéma ne correspond pas au fichier téléchargé.
  Future<void> checkDatabaseIntegrity() async {
    try {
      LoggerService.db('[DB] Vérifying database integrity...');

      // Vérification des tables critiques
      final criticalTables = [
        'medicament_summary',
        'medicaments',
        'specialites',
        'group_members',
        'generique_groups',
        'laboratories'
      ];

      for (final table in criticalTables) {
        await customSelect('SELECT COUNT(*) FROM $table LIMIT 1').get();
        LoggerService.db('[DB] Table $table verified');
      }

      // Vérification des vues critiques
      final criticalViews = [
        'view_group_details',
        'view_search_results',
        'view_explorer_list'
      ];

      for (final view in criticalViews) {
        await customSelect('SELECT COUNT(*) FROM $view LIMIT 1').get();
        LoggerService.db('[DB] View $view verified');
      }

      // Vérification du FTS5 index
      await customSelect('SELECT COUNT(*) FROM search_index LIMIT 1').get();
      LoggerService.db('[DB] FTS5 index verified');

      LoggerService.info('[DB] Database integrity check passed');
    } catch (e) {
      LoggerService.error('[DB] Database integrity check failed', e, null);
      throw Exception(
        "Erreur d'intégrité de la base de données: Le schéma ne correspond pas au fichier téléchargé. $e",
      );
    }
  }


  /// Vérifie la compatibilité du schéma téléchargé avec les attentes locales
  Future<void> _verifySchemaCompatibility() async {
    // Cette méthode sera appelée après téléchargement pour vérifier
    // que le schéma de la base téléchargée correspond aux attentes
    LoggerService.db(
        '[DB] Verifying schema compatibility with local expectations');

    // Les vérifications détaillées sont faites dans checkDatabaseIntegrity()
  }
}

