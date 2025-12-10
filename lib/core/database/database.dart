import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/database/daos/catalog_dao.dart';
import 'package:pharma_scan/core/database/daos/database_dao.dart';
import 'package:pharma_scan/core/database/daos/restock_dao.dart';
import 'package:pharma_scan/core/database/daos/settings_dao.dart';
import 'package:pharma_scan/core/database/database.drift.dart';
import 'package:pharma_scan/core/database/tables/restock_items.dart';
import 'package:pharma_scan/core/database/tables/scanned_boxes.dart';
import 'package:pharma_scan/core/database/tables/settings.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:sqlite3/common.dart';

export 'daos/catalog_dao.dart';
export 'daos/database_dao.dart';
export 'daos/restock_dao.dart';
export 'daos/settings_dao.dart';
export 'database.drift.dart';

// -- Type Converters --

class StringListJsonbConverter extends TypeConverter<List<String>, Uint8List>
    with JsonTypeConverter2<List<String>, Uint8List, List<dynamic>> {
  const StringListJsonbConverter();

  @override
  List<String> fromSql(Uint8List fromDb) {
    final decoded = json.decode(utf8.decode(fromDb));
    if (decoded is List) {
      return decoded
          .map((value) => (value?.toString() ?? '').trim())
          .where((value) => value.isNotEmpty)
          .cast<String>()
          .toList();
    }
    return const [];
  }

  @override
  Uint8List toSql(List<String> value) {
    return Uint8List.fromList(utf8.encode(json.encode(value)));
  }

  @override
  List<String> fromJson(List<dynamic> json) => json
      .map((value) => (value?.toString() ?? '').trim())
      .where((value) => value.isNotEmpty)
      .cast<String>()
      .toList();

  @override
  List<dynamic> toJson(List<String> value) => value;
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
  IntColumn get titulaireId =>
      integer().nullable().references(Laboratories, #id)();
  TextColumn get conditionsPrescription => text().nullable()();
  DateTimeColumn get dateAmm => dateTime().nullable()();
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
  TextColumn get rawLabel => text().nullable()();
  TextColumn get parsingMethod => text().nullable()();

  @override
  Set<Column> get primaryKey => {groupId};
}

@TableIndex(name: 'idx_group_members_group_id', columns: {#groupId})
@TableIndex(name: 'idx_group_members_code_cip', columns: {#codeCip})
class GroupMembers extends Table {
  TextColumn get codeCip => text().references(Medicaments, #codeCip)();
  TextColumn get groupId => text().references(GeneriqueGroups, #groupId)();
  IntColumn get type =>
      integer()(); // 0 princeps, 1 standard, 2 complémentarité, 4 substituable

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
  IntColumn get memberType =>
      integer().withDefault(const Constant(0))(); // raw BDPM generic type
  BlobColumn get principesActifsCommuns => blob().map(
    const StringListJsonbConverter(),
  )(); // JSONB array of common active ingredients
  TextColumn get princepsDeReference =>
      text()(); // reference princeps name for group
  TextColumn get formePharmaceutique => text().nullable()(); // for filtering
  TextColumn get voiesAdministration => text().nullable()(); // semicolon routes
  TextColumn get princepsBrandName => text()();
  TextColumn get procedureType => text().nullable()();
  IntColumn get titulaireId =>
      integer().nullable().references(Laboratories, #id)();
  TextColumn get conditionsPrescription => text().nullable()();
  DateTimeColumn get dateAmm => dateTime().nullable()();
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

class Laboratories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
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
    Laboratories,
    ScannedBoxes,
  ],
  daos: [SettingsDao, CatalogDao, DatabaseDao, RestockDao],
  include: {'queries.drift', 'views.drift'},
)
class AppDatabase extends $AppDatabase {
  AppDatabase()
    : super(
        driftDatabase(
          name: 'medicaments',
          native: DriftNativeOptions(
            databasePath: () async {
              final dir = await getApplicationDocumentsDirectory();
              return p.join(dir.path, 'medicaments.db');
            },
            shareAcrossIsolates: true,
            setup: configureAppSQLite,
          ),
        ),
      );

  // Test constructor
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;
}

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
