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
  TextColumn get etatCommercialisation => text().nullable()();
  TextColumn get titulaire => text().nullable()();
  TextColumn get conditionsPrescription => text().nullable()();

  @override
  Set<Column> get primaryKey => {cisCode};
}

@TableIndex(name: 'idx_medicaments_cis_code', columns: {#cisCode})
class Medicaments extends Table {
  TextColumn get codeCip => text()();
  // WHY: Removed nom column - specialites table is the single source of truth for medication names.
  // Every medicament (CIP) links to a specialite (CIS), so storing the name in both tables is redundant.
  TextColumn get cisCode => text().references(Specialites, #cisCode)();

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
@TableIndex(name: 'idx_medicament_summary_cluster_key', columns: {#clusterKey})
@TableIndex(
  name: 'idx_medicament_summary_forme_pharmaceutique',
  columns: {#formePharmaceutique},
)
@TableIndex(
  name: 'idx_medicament_summary_procedure_type',
  columns: {#procedureType},
)
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
    AppSettings,
  ],
  include: {'queries.drift'},
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Test constructor
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;
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
    return NativeDatabase.createInBackground(file, logStatements: false);
  });
}
