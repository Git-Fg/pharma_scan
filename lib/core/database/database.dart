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
  TextColumn get statutAdministratif => text().nullable()();
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
  TextColumn get presentationLabel => text().nullable()();
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
  TextColumn get lien => text().nullable()();

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
  TextColumn get status => text().nullable()();
  RealColumn get priceMin => real().nullable()();
  RealColumn get priceMax => real().nullable()();
  TextColumn get aggregatedConditions => text().nullable()();
  TextColumn get ansmAlertUrl => text().nullable()();
  BoolColumn get isHospitalOnly =>
      boolean().named('is_hospital').withDefault(const Constant(false))();
  BoolColumn get isDental =>
      boolean().named('is_dental').withDefault(const Constant(false))();
  BoolColumn get isList1 =>
      boolean().named('is_list1').withDefault(const Constant(false))();
  BoolColumn get isList2 =>
      boolean().named('is_list2').withDefault(const Constant(false))();
  BoolColumn get isNarcotic =>
      boolean().named('is_narcotic').withDefault(const Constant(false))();
  BoolColumn get isException =>
      boolean().named('is_exception').withDefault(const Constant(false))();
  BoolColumn get isRestricted =>
      boolean().named('is_restricted').withDefault(const Constant(false))();
  BoolColumn get isOtc =>
      boolean().named('is_otc').withDefault(const Constant(true))();

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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
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
