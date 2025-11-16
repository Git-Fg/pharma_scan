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

  @override
  Set<Column> get primaryKey => {cisCode};
}

class Medicaments extends Table {
  TextColumn get codeCip => text()();
  TextColumn get nom => text()();
  TextColumn get cisCode => text().references(Specialites, #cisCode)();

  @override
  Set<Column> get primaryKey => {codeCip};
}

class PrincipesActifs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get codeCip => text().references(Medicaments, #codeCip)();
  TextColumn get principe => text()();
  RealColumn get dosage => real().nullable()();
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

// -- Database Class --

@DriftDatabase(
  tables: [
    Specialites,
    Medicaments,
    PrincipesActifs,
    GeneriqueGroups,
    GroupMembers,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Test constructor
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (m, from, to) async {
        // WHY: Pour le développement, on recrée simplement la base de données
        // lors d'un changement de schéma. En production, on implémenterait
        // une vraie migration avec ALTER TABLE.
        if (from < 4) {
          // Supprimer toutes les tables et les recréer avec le nouveau schéma
          await m.deleteTable('group_members');
          await m.deleteTable('generique_groups');
          await m.deleteTable('principes_actifs');
          await m.deleteTable('medicaments');
          await m.deleteTable('specialites');
          await m.createAll();
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'medicaments.db'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}
