import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift/wasm.dart' if (dart.library.io) 'drift_native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/daos/database_dao.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import 'package:pharma_scan/core/database/database.drift.dart';

@DriftDatabase(
  daos: [CatalogDao, DatabaseDao, RestockDao],
  include: {'dbschema.drift', 'queries.drift', 'views.drift'},
)
class AppDatabase extends $AppDatabase {
  /// Constructeur principal utilisant driftDatabase pour la configuration multi-plateforme
  AppDatabase()
      : _isTestDatabase = false,
        super(_openConnection());

  /// Constructeur pour les tests
  AppDatabase.forTesting(super.e) : _isTestDatabase = true;

  /// Flag to identify test databases
  final bool _isTestDatabase;

  static QueryExecutor _openConnection() {
    if (kIsWeb) {
      return Future(() async {
        final result = await WasmDatabase.open(
          databaseName: 'pharma_scan_db_v3',
          sqlite3Uri: Uri.parse('sqlite3.wasm'),
          driftWorkerUri: Uri.parse('drift_worker.dart.js'),
          initializeDatabase: () async {
            final data = await rootBundle.load('assets/reference.db');
            return data.buffer.asUint8List();
          },
        );
        return result; // result implémente QueryExecutor
      }) as QueryExecutor;
    } else {
      return driftDatabase(
        name: 'pharma_scan_db_v3',
        native: const DriftNativeOptions(
          shareAcrossIsolates: true,
        ),
      );
    }
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        if (_isTestDatabase) {
          // For test databases, create all tables from schema
          for (final table in allTables) {
            if (table.actualTableName != 'sqlite_sequence') {
              await m.createTable(table);
            }
          }

          // Create FTS5 table for search functionality
          await customStatement('''
            CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
              cis_code UNINDEXED,
              molecule_name,
              brand_name,
              tokenize='trigram'
            )
          ''');

          // Create unique index for scanned_boxes duplicate detection
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS idx_scanned_boxes_unique ON scanned_boxes(cip_code, box_label)',
          );
        } else {
          // Production databases should not be created from scratch
          throw UnimplementedError(
            'Database creation from scratch is not supported in production. '
            'Production databases must be downloaded as pre-built assets.',
          );
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

  /// Vérifie l'intégrité de la base de données en tentant une requête simple.
  ///
  /// Lance une exception si le schéma ne correspond pas au fichier téléchargé.
  Future<void> checkDatabaseIntegrity() async {
    try {
      // Tente de lire une ligne simple pour vérifier que la structure correspond
      await customSelect('SELECT 1 FROM medicament_summary LIMIT 1').get();
    } catch (e) {
      // Erreur critique : Le fichier téléchargé est obsolète ou corrompu
      throw Exception(
        "Erreur d'intégrité de la base de données: Le schéma ne correspond pas au fichier téléchargé. $e",
      );
    }
  }
}

/// Test helper for creating in-memory databases with proper schema
///
/// This helper provides a clean way to create test databases that match the
/// production schema without contaminating production code with test logic.
class TestDatabaseHelper {
  /// Creates an in-memory test database with all tables and indexes properly set up
  static Future<AppDatabase> createTestDatabase() async {
    // Use a direct QueryExecutor to bypass the migration check
    final executor = NativeDatabase.memory();
    final database = AppDatabase.forTesting(executor);

    // Apply the same settings as production database
    await database.customStatement('PRAGMA foreign_keys = ON');
    await database.customStatement('PRAGMA journal_mode=WAL');
    await database.customStatement('PRAGMA busy_timeout=30000');
    await database.customStatement('PRAGMA synchronous=NORMAL');
    await database.customStatement('PRAGMA mmap_size=300000000');
    await database.customStatement('PRAGMA temp_store=MEMORY');

    // Create all tables from schema
    final migrator = Migrator(database);
    for (final table in database.allTables) {
      if (table.actualTableName != 'sqlite_sequence') {
        await migrator.createTable(table);
      }
    }

    // Create FTS5 table for search functionality
    await database.customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
        cis_code UNINDEXED,
        molecule_name,
        brand_name,
        tokenize='trigram'
      )
    ''');

    // Create unique index for scanned_boxes duplicate detection
    await database.customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_scanned_boxes_unique ON scanned_boxes(cip_code, box_label)',
    );

    return database;
  }
}
