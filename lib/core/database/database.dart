// lib/core/database/database.dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

// -- Table Definitions --

class Specialites extends Table {
  TextColumn get cisCode => text()();
  TextColumn get nomSpecialite => text()();
  TextColumn get procedureType => text()();
  TextColumn get formePharmaceutique => text().nullable()();
  TextColumn get etatCommercialisation => text().nullable()();
  TextColumn get titulaire => text().nullable()();
  TextColumn get conditionsPrescription => text().nullable()();

  @override
  Set<Column> get primaryKey => {cisCode};
}

class Medicaments extends Table {
  TextColumn get codeCip => text()();
  // WHY: Removed nom column - specialites table is the single source of truth for medication names.
  // Every medicament (CIP) links to a specialite (CIS), so storing the name in both tables is redundant.
  TextColumn get cisCode => text().references(Specialites, #cisCode)();

  @override
  Set<Column> get primaryKey => {codeCip};
}

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

class GroupMembers extends Table {
  TextColumn get codeCip => text().references(Medicaments, #codeCip)();
  TextColumn get groupId => text().references(GeneriqueGroups, #groupId)();
  IntColumn get type => integer()(); // 0 for princeps, 1 for generic

  @override
  Set<Column> get primaryKey => {codeCip};
}

class MedicamentSummary extends Table {
  TextColumn get cisCode => text()();
  TextColumn get nomCanonique => text()();
  BoolColumn get isPrinceps => boolean()();
  TextColumn get groupId =>
      text().nullable()(); // nullable for medications without groups
  TextColumn get principesActifsCommuns =>
      text()(); // JSON array of common active ingredients
  TextColumn get princepsDeReference =>
      text()(); // reference princeps name for group
  TextColumn get formePharmaceutique => text().nullable()(); // for filtering
  TextColumn get princepsBrandName => text()();
  TextColumn get clusterKey => text()();
  TextColumn get procedureType => text().nullable()();
  TextColumn get titulaire => text().nullable()();
  TextColumn get conditionsPrescription => text().nullable()();

  @override
  Set<Column> get primaryKey => {cisCode};
}

// -- Database Class --

@DriftDatabase(
  tables: [
    Specialites,
    Medicaments,
    PrincipesActifs,
    GeneriqueGroups,
    GroupMembers,
    MedicamentSummary,
  ],
  include: {'queries.drift'},
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Test constructor
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (m, from, to) async {
        // WHY: Migration from v1 to v2 - remove redundant nom column from medicaments table.
        // The specialites table is the single source of truth for medication names.
        // Since SQLite doesn't support DROP COLUMN directly, we use a custom migration.
        if (from < 2) {
          // Recreate medicaments table without nom column
          await customStatement('''
            CREATE TABLE medicaments_new (
              code_cip TEXT NOT NULL PRIMARY KEY,
              cis_code TEXT NOT NULL REFERENCES specialites(cis_code)
            )
          ''');
          await customStatement('''
            INSERT INTO medicaments_new (code_cip, cis_code)
            SELECT code_cip, cis_code FROM medicaments
          ''');
          await customStatement('DROP TABLE medicaments');
          await customStatement(
            'ALTER TABLE medicaments_new RENAME TO medicaments',
          );
        }
        if (from < 3) {
          await m.alterTable(
            TableMigration(
              specialites,
              newColumns: [specialites.conditionsPrescription],
            ),
          );
        }
        if (from < 4) {
          await customStatement('''
            CREATE TABLE medicament_summary (
              cis_code TEXT NOT NULL PRIMARY KEY,
              nom_canonique TEXT NOT NULL,
              is_princeps INTEGER NOT NULL,
              group_id TEXT,
              principes_actifs_communs TEXT NOT NULL,
              princeps_de_reference TEXT NOT NULL,
              forme_pharmaceutique TEXT,
              princeps_brand_name TEXT NOT NULL DEFAULT '',
              cluster_key TEXT NOT NULL DEFAULT ''
            )
          ''');
        }
        if (from < 5) {
          await customStatement('''
            CREATE TABLE principes_actifs_new (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              code_cip TEXT NOT NULL REFERENCES medicaments(code_cip),
              principe TEXT NOT NULL,
              dosage TEXT,
              dosage_unit TEXT
            )
          ''');
          await customStatement('''
            INSERT INTO principes_actifs_new (id, code_cip, principe, dosage, dosage_unit)
            SELECT id, code_cip, principe, CAST(dosage AS TEXT), dosage_unit
            FROM principes_actifs
          ''');
          await customStatement('DROP TABLE principes_actifs');
          await customStatement(
            'ALTER TABLE principes_actifs_new RENAME TO principes_actifs',
          );
        }
        if (from < 6) {
          await customStatement('''
            ALTER TABLE medicament_summary
            ADD COLUMN princeps_brand_name TEXT NOT NULL DEFAULT ''
            ''');
          await customStatement('''
            ALTER TABLE medicament_summary
            ADD COLUMN cluster_key TEXT NOT NULL DEFAULT ''
            ''');
        }
        if (from < 7) {
          await customStatement('''
            ALTER TABLE medicament_summary
            ADD COLUMN procedure_type TEXT
            ''');
          await customStatement('''
            ALTER TABLE medicament_summary
            ADD COLUMN titulaire TEXT
            ''');
          await customStatement('''
            ALTER TABLE medicament_summary
            ADD COLUMN conditions_prescription TEXT
            ''');

          // Populate new columns from specialites table
          await customStatement('''
            UPDATE medicament_summary
            SET 
              procedure_type = (SELECT procedure_type FROM specialites WHERE cis_code = medicament_summary.cis_code),
              titulaire = (SELECT titulaire FROM specialites WHERE cis_code = medicament_summary.cis_code),
              conditions_prescription = (SELECT conditions_prescription FROM specialites WHERE cis_code = medicament_summary.cis_code)
          ''');
        }
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

    return NativeDatabase.createInBackground(file);
  });
}
