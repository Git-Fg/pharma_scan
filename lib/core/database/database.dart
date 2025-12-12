import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Conditional imports for web vs mobile
import 'package:drift/wasm.dart' if (dart.library.io) 'drift_native.dart';

// ... imports ...

// ... imports ...
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
  AppDatabase() : super(_openConnection());

  /// Constructeur pour les tests
  AppDatabase.forTesting(super.e);

  @override
  late final CatalogDao catalogDao = CatalogDao(this);
  @override
  late final DatabaseDao databaseDao = DatabaseDao(this);
  @override
  late final RestockDao restockDao = RestockDao(this);

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
        return result.executor;
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
        // Pour les tests avec base de données en mémoire, créer toutes les tables
        // depuis le schéma défini dans les fichiers .drift
        // Exclure sqlite_sequence car c'est une table système gérée automatiquement par SQLite
        for (final table in allTables) {
          if (table.actualTableName != 'sqlite_sequence') {
            await m.createTable(table);
          }
        }

        // Créer la table virtuelle FTS5 search_index pour les tests
        await _createFts5Table();

        // Créer les index uniques nécessaires pour les tests
        await _createUniqueIndexes();
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

  /// Crée la table virtuelle FTS5 search_index (pour les tests uniquement).
  /// En production, la table est déjà créée dans la base téléchargée.
  Future<void> _createFts5Table() async {
    try {
      await customStatement(
        '''
        CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
          cis_code UNINDEXED,
          molecule_name,
          brand_name,
          tokenize='trigram'
        )
        ''',
      );
    } catch (_) {
      // En cas d'erreur, ignorer silencieusement
      // La table sera déjà créée dans la base téléchargée
    }
  }

  /// Crée les index uniques nécessaires pour les tests.
  /// En production, ces index sont déjà créés dans la base téléchargée.
  Future<void> _createUniqueIndexes() async {
    try {
      // Drop existing index if any to recreate cleanly
      await customStatement('DROP INDEX IF EXISTS idx_scanned_boxes_unique');

      // Create unique constraint for scanned_boxes duplicate detection
      await customStatement(
        'CREATE UNIQUE INDEX idx_scanned_boxes_unique ON scanned_boxes(cip_code, box_label)',
      );
    } catch (_) {
      // En cas d'erreur, ignorer silencieusement
      // Les index seront déjà créés dans la base téléchargée
    }
  }
}
