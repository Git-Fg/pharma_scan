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
        // Toutes les tables sont déjà créées par le schéma SQL inclus depuis GitHub
        // Rien à faire ici car la DB est pré-remplie/téléchargée
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
