import 'dart:convert';
import 'dart:io';

import 'package:diacritic/diacritic.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/daos/database_dao.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import 'package:pharma_scan/core/database/daos/settings_dao.dart';
import 'package:pharma_scan/core/database/tables/restock_items.dart';
import 'package:pharma_scan/core/database/tables/settings.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

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
    } on Exception catch (_) {
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
@TableIndex(
  name: 'idx_principes_normalized_cip',
  columns: {#principeNormalized, #codeCip},
)
class PrincipesActifs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get codeCip => text().references(Medicaments, #codeCip)();
  TextColumn get principe => text()();
  TextColumn get principeNormalized => text().nullable()();
  TextColumn get dosage => text().nullable()();
  TextColumn get dosageUnit => text().nullable()();
}

class GeneriqueGroups extends Table {
  TextColumn get groupId => text()();
  TextColumn get libelle => text()();
  TextColumn get princepsLabel => text().nullable()();
  TextColumn get moleculeLabel => text().nullable()();

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
@TableIndex(
  name: 'idx_medicament_summary_principes_actifs_communs',
  columns: {#principesActifsCommuns},
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
  TextColumn get representativeCip =>
      text().nullable()(); // Representative CIP code for standalone medications

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
    RestockItems,
  ],
  daos: [SettingsDao, CatalogDao, DatabaseDao, RestockDao],
  include: {'queries.drift', 'views.drift'},
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
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 3) {
          await m.createTable(restockItems);
        }
        if (from < 4) {
          await m.addColumn(appSettings, appSettings.preferredSorting);
        }
      },
    );
  }
}

void _registerNormalizeTextFunction(Database database) {
  database.createFunction(
    functionName: 'normalize_text',
    argumentCount: const AllowedArgumentCount(1),
    deterministic: true,
    directOnly: false,
    function: (args) {
      final source = args.isEmpty ? '' : args.first?.toString() ?? '';
      if (source.isEmpty) return '';
      return removeDiacritics(source)
          .toLowerCase()
          .replaceAll("'", ' ')
          .replaceAll('"', ' ')
          .replaceAll(':', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    },
  );
}

void configureAppSQLite(Database database) {
  database
    ..execute('PRAGMA journal_mode=WAL')
    ..execute('PRAGMA busy_timeout=30000');
  _registerNormalizeTextFunction(database);
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
    return NativeDatabase.createInBackground(
      file,
      setup: configureAppSQLite,
    );
  });
}
