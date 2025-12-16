import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';

import 'package:pharma_scan/core/database/daos/app_settings_dao.dart';
import 'package:pharma_scan/core/database/tables/app_settings_table.dart';
import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/daos/database_dao.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import 'package:pharma_scan/core/database/database.drift.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/database/daos/explorer_dao.dart';
import 'package:pharma_scan/core/database/user_schema.drift.dart';

@DriftDatabase(
  // Include schema files - reference tables are defined in reference_schema.drift
  include: {
    'reference_schema.drift',
    'user_schema.drift',
    'queries.drift',
    'restock_views.drift'
  },
  tables: [AppSettings],
  daos: [CatalogDao, DatabaseDao, RestockDao, ExplorerDao, AppSettingsDao],
)
class AppDatabase extends $AppDatabase {
  AppDatabase(this.logger) : super(_openConnection(logger));

  /// Constructeur pour les tests utilisant une base de données en mémoire
  AppDatabase.forTesting(QueryExecutor executor, this.logger) : super(executor);

  final LoggerService logger;

  static QueryExecutor _openConnection(LoggerService logger) {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();

      // 1. Define paths for BOTH databases
      final userDbFile = File(p.join(dbFolder.path, 'user.db'));
      final referenceDbFile = File(p.join(dbFolder.path, 'reference.db'));

      // Check for hydration
      if (!await referenceDbFile.exists()) {
        logger.info('Reference DB missing, hydrating from assets...');
        try {
          final data = await rootBundle.load('assets/database/reference.db.gz');
          final bytes = data.buffer.asUint8List();
          final decoded = GZipDecoder().decodeBytes(bytes);
          await referenceDbFile.writeAsBytes(decoded, flush: true);
          logger.info('Hydration complete.');
        } catch (e, stack) {
          logger.error('Failed to hydrate DB', e, stack);
          // If hydration fails, we probably shouldn't proceed with an empty DB
          throw Exception('Failed to hydrate reference database: $e');
        }
      }

      // 2. Open USER.DB as the primary connection
      return NativeDatabase(
        userDbFile,
        setup: (database) {
          // 3. Attach REFERENCE.DB dynamically when connection opens
          // 'reference_db' is the alias we will use in queries if needed,
          // though Drift handles this transparently for known tables.
          database.execute(
              "ATTACH DATABASE '${referenceDbFile.path}' AS reference_db");
        },
      );
    });
  }

  @override
  int get schemaVersion => 1; // Kept at 1 as per requirements

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        // 4. CRITICAL: Only create USER tables.
        // The reference tables already exist in the attached file.
        await m.createTable(restockItems);
        await m.createTable(scannedBoxes);
        await m.createTable(appSettings);

        // Create generated indices for user tables
        // Note: Indices defined in .drift files outside of CREATE TABLE must be created manually
        await m.createIndex(idxScannedBoxesUnique);
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        // Configuration SQLite optimale
        await customStatement('PRAGMA journal_mode=WAL');
        await customStatement('PRAGMA busy_timeout=30000');
        await customStatement('PRAGMA synchronous=NORMAL');
        await customStatement('PRAGMA mmap_size=300000000');
        await customStatement('PRAGMA temp_store=MEMORY');

        // Check integrity of the attached reference DB first
        await _verifyReferenceIntegrity();
      },
    );
  }

  Future<void> _verifyReferenceIntegrity() async {
    // Run a quick check to ensure attachment worked
    try {
      await customSelect('SELECT count(*) FROM reference_db.medicament_summary')
          .get();
    } catch (e) {
      // Handle missing reference.db (e.g., first launch)
      // You might want to trigger the download service here if it fails
      logger.warning('[DB] Reference database not attached or missing: $e');
    }
  }

  /// Vérifie l'intégrité complète de la base de données téléchargée.
  ///
  /// Vérifie que toutes les tables et vues critiques existent et ont la structure attendue.
  /// Lance une exception si le schéma ne correspond pas au fichier téléchargé.
  Future<void> checkDatabaseIntegrity() async {
    try {
      logger.db('[DB] Vérifying database integrity...');

      // Vérification des tables critiques dans reference.db
      final criticalTables = [
        'medicament_summary',
        'medicaments',
        'specialites',
        'group_members',
        'generique_groups',
        'laboratories'
      ];

      for (final table in criticalTables) {
        await customSelect('SELECT COUNT(*) FROM reference_db.$table LIMIT 1')
            .get();
        logger.db('[DB] Table reference_db.$table verified');
      }

      // Vérification des vues critiques (devraient être définies dans reference_schema.drift)
      // Note: Ces "vues" sont maintenant des tables matérialisées (ui_*) pour la performance
      final criticalUiTables = ['ui_group_details', 'ui_explorer_list'];

      for (final table in criticalUiTables) {
        await customSelect('SELECT COUNT(*) FROM $table LIMIT 1').get();
        logger.db('[DB] UI Table $table verified');
      }

      // Vérification du FTS5 index
      await customSelect(
              'SELECT COUNT(*) FROM reference_db.search_index LIMIT 1')
          .get();
      logger.db('[DB] FTS5 index verified');

      logger.info('[DB] Database integrity check passed');
    } catch (e) {
      logger.error('[DB] Database integrity check failed', e, null);
      throw Exception(
        "Erreur d'intégrité de la base de données: Le schéma ne correspond pas au fichier téléchargé. $e",
      );
    }
  }
}
