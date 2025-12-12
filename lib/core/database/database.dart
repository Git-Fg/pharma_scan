import 'dart:io';

import 'package:drift/drift.dart';
import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/daos/database_dao.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import 'package:pharma_scan/core/database/daos/settings_dao.dart';
import 'package:pharma_scan/core/database/database.drift.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:sqlite3/common.dart';

export 'daos/catalog_dao.dart';
export 'daos/database_dao.dart';
export 'daos/restock_dao.dart';
export 'daos/settings_dao.dart';
export 'database.drift.dart';

// -- Database Class --

/// Base de données principale de l'application.
///
/// Toutes les tables (BDPM et Flutter) sont définies dans `dbschema.drift`
/// (synchronisé depuis GitHub) et générées automatiquement par Drift pour garantir
/// la type safety optimale. Le schéma SQL est la source de vérité unique.
@DriftDatabase(
  daos: [SettingsDao, CatalogDao, DatabaseDao, RestockDao],
  include: {'dbschema.drift', 'queries.drift', 'views.drift'},
)
class AppDatabase extends $AppDatabase {
  /// Constructeur principal acceptant l'exécuteur (la connexion physique)
  AppDatabase(super.e);

  /// Constructeur pour les tests
  AppDatabase.forTesting(super.e);

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

        // Créer les vues depuis views.drift pour les tests
        await _createViews(m);

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

  /// Crée les vues SQL depuis views.drift (pour les tests uniquement).
  /// En production, les vues sont déjà créées dans la base téléchargée.
  Future<void> _createViews(Migrator m) async {
    try {
      // Lire le fichier views.drift depuis le système de fichiers
      // Le chemin est relatif à lib/core/database/
      final viewsFile = File('lib/core/database/views.drift');
      if (!await viewsFile.exists()) {
        // En production ou si le fichier n'est pas accessible, ignorer
        return;
      }

      final content = await viewsFile.readAsString();

      // Extraire chaque CREATE VIEW statement (de "CREATE VIEW" jusqu'au ";")
      final viewPattern = RegExp(
        r'CREATE VIEW\s+\w+\s+AS\s+.*?;',
        dotAll: true,
        caseSensitive: false,
      );

      final matches = viewPattern.allMatches(content);
      for (final match in matches) {
        final viewSql = match.group(0)!;
        // Exécuter la création de la vue
        await customStatement(viewSql);
      }
    } catch (e) {
      // En cas d'erreur (fichier non accessible en production), ignorer silencieusement
      // Les vues seront déjà créées dans la base téléchargée
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
    } catch (e) {
      // En cas d'erreur, ignorer silencieusement
      // La table sera déjà créée dans la base téléchargée
    }
  }

  /// Crée les index uniques nécessaires pour les tests.
  /// En production, ces index sont déjà créés dans la base téléchargée.
  Future<void> _createUniqueIndexes() async {
    try {
      // Unique constraint for scanned_boxes duplicate detection
      await customStatement(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_scanned_boxes_unique ON scanned_boxes(cip_code, box_label)',
      );
    } catch (e) {
      // En cas d'erreur, ignorer silencieusement
      // Les index seront déjà créés dans la base téléchargée
    }
  }
}

/// Configure SQLite avec les optimisations et fonctions personnalisées.
void configureAppSQLite(CommonDatabase database) {
  database
    ..execute('PRAGMA journal_mode=WAL')
    ..execute('PRAGMA busy_timeout=30000')
    ..execute('PRAGMA synchronous=NORMAL')
    ..execute('PRAGMA mmap_size=300000000')
    ..execute('PRAGMA temp_store=MEMORY')
    ..createFunction(
      functionName: 'normalize_text',
      argumentCount: const AllowedArgumentCount(1),
      deterministic: true,
      directOnly: false,
      function: (List<Object?> args) {
        final source = args.isEmpty ? '' : args.first?.toString() ?? '';
        if (source.isEmpty) return '';
        return normalizeForSearch(source);
      },
    );
}
