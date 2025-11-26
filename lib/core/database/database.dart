// lib/core/database/database.dart
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:pharma_scan/core/database/tables/settings.dart';
import 'package:pharma_scan/core/database/daos/settings_dao.dart';
import 'package:pharma_scan/core/database/daos/search_dao.dart';
import 'package:pharma_scan/core/database/daos/library_dao.dart';
import 'package:pharma_scan/core/database/daos/scan_dao.dart';
import 'package:pharma_scan/core/database/daos/database_dao.dart';

part 'database.g.dart';

// -- Type Converters --

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String? fromDb) {
    if (fromDb == null || fromDb.isEmpty) return [];
    try {
      final decoded = jsonDecode(fromDb);
      if (decoded is List) {
        return decoded
            .map((value) => (value?.toString() ?? '').trim())
            .where((value) => value.isNotEmpty)
            .cast<String>()
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

// -- Table Definitions --

class Specialites extends Table {
  TextColumn get cisCode => text()();
  TextColumn get nomSpecialite => text()();
  TextColumn get procedureType => text()();
  TextColumn get formePharmaceutique => text().nullable()();
  TextColumn get voiesAdministration => text().nullable()();
  TextColumn get etatCommercialisation => text().nullable()();
  TextColumn get titulaire => text().nullable()();
  TextColumn get conditionsPrescription => text().nullable()();
  TextColumn get atcCode => text().nullable()();
  BoolColumn get isSurveillance =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {cisCode};
}

@TableIndex(name: 'idx_medicaments_cis_code', columns: {#cisCode})
class Medicaments extends Table {
  TextColumn get codeCip => text()();
  // WHY: Removed nom column - specialites table is the single source of truth for medication names.
  // Every medicament (CIP) links to a specialite (CIS), so storing the name in both tables is redundant.
  TextColumn get cisCode => text().references(Specialites, #cisCode)();
  TextColumn get commercialisationStatut => text().nullable()();
  TextColumn get tauxRemboursement => text().nullable()();
  RealColumn get prixPublic => real().nullable()();
  TextColumn get agrementCollectivites => text().nullable()();

  @override
  Set<Column> get primaryKey => {codeCip};
}

class MedicamentAvailability extends Table {
  TextColumn get codeCip => text().references(Medicaments, #codeCip)();
  TextColumn get statut => text()();
  DateTimeColumn get dateDebut => dateTime().nullable()();
  DateTimeColumn get dateFin => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {codeCip};
}

@TableIndex(name: 'idx_principes_code_cip', columns: {#codeCip})
class PrincipesActifs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get codeCip => text().references(Medicaments, #codeCip)();
  TextColumn get principe => text()();
  TextColumn get dosage => text().nullable()();
  TextColumn get dosageUnit => text().nullable()();
}

class GeneriqueGroups extends Table {
  TextColumn get groupId => text()();
  TextColumn get libelle => text()();

  @override
  Set<Column> get primaryKey => {groupId};
}

@TableIndex(name: 'idx_group_members_group_id', columns: {#groupId})
@TableIndex(name: 'idx_group_members_code_cip', columns: {#codeCip})
class GroupMembers extends Table {
  TextColumn get codeCip => text().references(Medicaments, #codeCip)();
  TextColumn get groupId => text().references(GeneriqueGroups, #groupId)();
  IntColumn get type => integer()(); // 0 for princeps, 1 for generic

  @override
  Set<Column> get primaryKey => {codeCip};
}

@TableIndex(name: 'idx_medicament_summary_group_id', columns: {#groupId})
@TableIndex(
  name: 'idx_medicament_summary_forme_pharmaceutique',
  columns: {#formePharmaceutique},
)
@TableIndex(
  name: 'idx_medicament_summary_voies_administration',
  columns: {#voiesAdministration},
)
@TableIndex(
  name: 'idx_medicament_summary_procedure_type',
  columns: {#procedureType},
)
@TableIndex(name: 'idx_summary_princeps_ref', columns: {#princepsDeReference})
class MedicamentSummary extends Table {
  TextColumn get cisCode => text()();
  TextColumn get nomCanonique => text()();
  BoolColumn get isPrinceps => boolean()();
  TextColumn get groupId =>
      text().nullable()(); // nullable for medications without groups
  TextColumn get principesActifsCommuns => text().map(
    const StringListConverter(),
  )(); // JSON array of common active ingredients
  TextColumn get princepsDeReference =>
      text()(); // reference princeps name for group
  TextColumn get formePharmaceutique => text().nullable()(); // for filtering
  TextColumn get voiesAdministration => text().nullable()(); // semicolon routes
  TextColumn get princepsBrandName => text()();
  TextColumn get procedureType => text().nullable()();
  TextColumn get titulaire => text().nullable()();
  TextColumn get conditionsPrescription => text().nullable()();
  BoolColumn get isSurveillance =>
      boolean().withDefault(const Constant(false))();
  TextColumn get formattedDosage => text().nullable()();
  TextColumn get atcCode => text().nullable()();

  @override
  Set<Column> get primaryKey => {cisCode};
}

// -- Database Class --

@DriftDatabase(
  tables: [
    Specialites,
    Medicaments,
    MedicamentAvailability,
    PrincipesActifs,
    GeneriqueGroups,
    GroupMembers,
    MedicamentSummary,
    AppSettings,
  ],
  daos: [SettingsDao, SearchDao, LibraryDao, ScanDao, DatabaseDao],
  include: {'queries.drift', 'views.drift'},
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Test constructor
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // WHY: Create views defined in views.drift
        // Views are not automatically created, so we need to create them explicitly
        await customStatement('''
          CREATE VIEW IF NOT EXISTS view_aggregated_grouped AS
          WITH
          group_cip_counts AS (
            SELECT
              gm.group_id,
              COUNT(DISTINCT gm.code_cip) AS total_cips
            FROM group_members gm
            GROUP BY gm.group_id
          ),
          principle_counts AS (
            SELECT
              gm.group_id,
              pa.principe,
              COUNT(DISTINCT m.code_cip) AS cip_count
            FROM principes_actifs pa
            INNER JOIN medicaments m ON pa.code_cip = m.code_cip
            INNER JOIN group_members gm ON m.code_cip = gm.code_cip
            WHERE pa.principe IS NOT NULL AND pa.principe != ''
            GROUP BY gm.group_id, pa.principe
          ),
          common_principles AS (
            SELECT
              pc.group_id,
              json_group_array(pc.principe) AS principes
            FROM (
              SELECT group_id, principe, cip_count 
              FROM principle_counts 
              ORDER BY principe ASC
            ) pc
            INNER JOIN group_cip_counts gcc ON pc.group_id = gcc.group_id
            WHERE pc.cip_count = gcc.total_cips
            GROUP BY pc.group_id
          ),
          princeps_ref AS (
            SELECT
              gm.group_id,
              MIN(s.nom_specialite) as nom_princeps
            FROM group_members gm
            JOIN medicaments m ON gm.code_cip = m.code_cip
            JOIN specialites s ON m.cis_code = s.cis_code
            WHERE gm.type = 0
            GROUP BY gm.group_id
          ),
          dosage_values AS (
            SELECT
              cis_code,
              GROUP_CONCAT(dosage_text, ' + ') AS formatted_dosage
            FROM (
              SELECT
                m.cis_code AS cis_code,
                CASE
                  WHEN TRIM(COALESCE(pa.dosage, '')) = ''
                    THEN NULL
                  ELSE
                    TRIM(RTRIM(RTRIM(pa.dosage, '0'), '.')) ||
                    CASE
                      WHEN TRIM(COALESCE(pa.dosage_unit, '')) = ''
                        THEN ''
                      ELSE ' ' || TRIM(pa.dosage_unit)
                    END
                END AS dosage_text
              FROM principes_actifs pa
              INNER JOIN medicaments m ON pa.code_cip = m.code_cip
            )
            WHERE dosage_text IS NOT NULL
            GROUP BY cis_code
          )
          SELECT
            s.cis_code,
            COALESCE(gg.libelle, s.nom_specialite) AS nom_canonique,
            CASE WHEN gm.type = 0 THEN 1 ELSE 0 END AS is_princeps,
            gg.group_id,
            COALESCE(cp.principes, '[]') AS principes_actifs_communs,
            COALESCE(gg.libelle, pref.nom_princeps, s.nom_specialite, 'Inconnu')
              AS princeps_de_reference,
            s.forme_pharmaceutique,
            COALESCE(gg.libelle, pref.nom_princeps, s.nom_specialite, 'Inconnu')
              AS princeps_brand_name,
            s.procedure_type,
            s.titulaire,
            s.conditions_prescription,
            s.is_surveillance,
            s.voies_administration,
            dv.formatted_dosage,
            s.atc_code
          FROM generique_groups gg
          INNER JOIN group_members gm ON gg.group_id = gm.group_id
          INNER JOIN medicaments m ON gm.code_cip = m.code_cip
          INNER JOIN specialites s ON m.cis_code = s.cis_code
          LEFT JOIN common_principles cp ON gg.group_id = cp.group_id
          LEFT JOIN princeps_ref pref ON gg.group_id = pref.group_id
          LEFT JOIN dosage_values dv ON dv.cis_code = s.cis_code;
        ''');

        await customStatement('''
          CREATE VIEW IF NOT EXISTS view_aggregated_standalone AS
          WITH
          dosage_values AS (
            SELECT
              cis_code,
              GROUP_CONCAT(dosage_text, ' + ') AS formatted_dosage
            FROM (
              SELECT
                m.cis_code AS cis_code,
                CASE
                  WHEN TRIM(COALESCE(pa.dosage, '')) = ''
                    THEN NULL
                  ELSE
                    TRIM(RTRIM(RTRIM(pa.dosage, '0'), '.')) ||
                    CASE
                      WHEN TRIM(COALESCE(pa.dosage_unit, '')) = ''
                        THEN ''
                      ELSE ' ' || TRIM(pa.dosage_unit)
                    END
                END AS dosage_text
              FROM principes_actifs pa
              INNER JOIN medicaments m ON pa.code_cip = m.code_cip
            )
            WHERE dosage_text IS NOT NULL
            GROUP BY cis_code
          )
          SELECT
            s.cis_code,
            s.nom_specialite AS nom_canonique,
            1 AS is_princeps,
            NULL AS group_id,
            COALESCE((
              SELECT json_group_array(DISTINCT pa.principe)
              FROM principes_actifs pa
              INNER JOIN medicaments m2 ON pa.code_cip = m2.code_cip
              WHERE m2.cis_code = s.cis_code
                AND pa.principe IS NOT NULL
                AND pa.principe != ''
              ORDER BY pa.principe
            ), '[]') AS principes_actifs_communs,
            s.nom_specialite AS princeps_de_reference,
            s.forme_pharmaceutique,
            s.nom_specialite AS princeps_brand_name,
            s.procedure_type,
            s.titulaire,
            s.conditions_prescription,
            s.is_surveillance,
            s.voies_administration,
            dv.formatted_dosage,
            s.atc_code
          FROM specialites s
          INNER JOIN medicaments m ON s.cis_code = m.cis_code
          LEFT JOIN dosage_values dv ON dv.cis_code = s.cis_code
          WHERE NOT EXISTS (
            SELECT 1
            FROM group_members gm
            INNER JOIN medicaments m2 ON gm.code_cip = m2.code_cip
            WHERE m2.cis_code = s.cis_code
          );
        ''');
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'medicaments.db'));

    if (!await dbFolder.exists()) {
      await dbFolder.create(recursive: true);
    }

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    LoggerService.db('SQLite Database Opened at ${file.path}');
    // WHY: Enable WAL mode to support concurrent access from multiple isolates
    // This prevents "database is locked" exceptions when background isolate
    // performs aggregation while main isolate reads/writes
    return NativeDatabase.createInBackground(
      file,
      logStatements: false,
      setup: (database) {
        database.execute('PRAGMA journal_mode=WAL');
        // WHY: Set busy timeout to allow main thread to wait for locks to release
        // This gives SQLite up to 30 seconds to wait instead of failing immediately
        database.execute('PRAGMA busy_timeout=30000');
      },
    );
  });
}
