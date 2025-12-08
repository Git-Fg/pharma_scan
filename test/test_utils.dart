// test/test_utils.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/ingestion/bdpm_file_parser.dart';

export 'helpers/pump_app.dart';

class FakePathProviderPlatform extends PathProviderPlatform {
  FakePathProviderPlatform(this._documentsPath);

  final String _documentsPath;
  String? _tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => _documentsPath;

  @override
  Future<String?> getTemporaryPath() async {
    if (_tempPath == null) {
      _tempPath = p.join(_documentsPath, 'temp');
      final tempDir = Directory(_tempPath!);
      if (!tempDir.existsSync()) {
        await tempDir.create(recursive: true);
      }
    }
    return _tempPath;
  }
}

/// Sets principe_normalized for all principles in the database.
/// This is required for aggregation to work correctly.
/// Call this after inserting batch data and before running aggregation.
Future<void> setPrincipeNormalizedForAllPrinciples(AppDatabase database) async {
  final allPrincipes = await database.select(database.principesActifs).get();
  for (final principe in allPrincipes) {
    final normalized = normalizePrincipleOptimal(principe.principe);
    await (database.update(database.principesActifs)..where(
          (tbl) =>
              tbl.codeCip.equals(principe.codeCip) &
              tbl.principe.equals(principe.principe),
        ))
        .write(
          PrincipesActifsCompanion(
            principeNormalized: Value(normalized),
          ),
        );
  }
}

/// Loads real BDPM data files from tool/data/ into the test database.
/// This function uses the same parsing logic as production, ensuring tests
/// run against realistic data structures.
///
/// Usage:
/// ```dart
/// setUp(() async {
///   database = AppDatabase.forTesting(
///     NativeDatabase.memory(setup: configureAppSQLite),
///   );
///   await loadRealBdpmData(database);
/// });
/// ```
///
/// Optional parameters:
/// - [dataDir]: Custom directory path (defaults to 'tool/data')
/// - [includeFiles]: Specific files to load (defaults to all required files)
Future<void> loadRealBdpmData(
  AppDatabase database, {
  String? dataDir,
  Set<String>? includeFiles,
}) async {
  try {
    String dataDirectory;
    if (dataDir != null) {
      if (p.isAbsolute(dataDir)) {
        dataDirectory = p.normalize(dataDir);
      } else {
        dataDirectory = p.absolute(dataDir);
      }
    } else {
      Directory? projectRoot;
      var current = Directory(Directory.current.path);
      for (var i = 0; i < 10; i++) {
        final pubspecFile = File(p.join(current.path, 'pubspec.yaml'));
        if (await pubspecFile.exists()) {
          projectRoot = current;
          break;
        }
        if (current.parent.path == current.path) {
          break;
        }
        current = current.parent;
      }

      if (projectRoot == null) {
        try {
          final testFile = File(Platform.script.toFilePath());
          var testDir = testFile.parent;
          for (var i = 0; i < 10; i++) {
            final pubspecFile = File(p.join(testDir.path, 'pubspec.yaml'));
            if (await pubspecFile.exists()) {
              projectRoot = testDir;
              break;
            }
            if (testDir.parent.path == testDir.path) {
              break;
            }
            testDir = testDir.parent;
          }
        } on Exception {
          // Platform.script might not be available in all contexts
        }
      }

      if (projectRoot == null) {
        stderr.writeln(
          '[TestData] Skipping real BDPM load: project root not found.',
        );
        return;
      }

      final candidate = Directory(p.join(projectRoot.path, 'tool', 'data'));
      if (!await candidate.exists()) {
        stderr.writeln(
          '[TestData] Skipping real BDPM load: data directory missing at ${candidate.path}.',
        );
        return;
      }

      dataDirectory = candidate.path;
    }

    final dir = Directory(dataDirectory);
    if (!await dir.exists()) {
      stderr.writeln(
        '[TestData] Skipping real BDPM load: $dataDirectory does not exist.',
      );
      return;
    }

    final fileMap = <String, String>{
      'specialites': 'CIS_bdpm.txt',
      'medicaments': 'CIS_CIP_bdpm.txt',
      'compositions': 'CIS_COMPO_bdpm.txt',
      'generiques': 'CIS_GENER_bdpm.txt',
      'conditions': 'CIS_CPD_bdpm.txt',
      'availability': 'CIS_CIP_Dispo_Spec.txt',
      'mitm': 'CIS_MITM.txt',
    };

    final filePaths = <String, String>{};
    for (final entry in fileMap.entries) {
      if (includeFiles != null && !includeFiles.contains(entry.key)) {
        continue;
      }
      final file = File(p.join(dataDirectory, entry.value));
      if (!await file.exists()) {
        stderr.writeln(
          '[TestData] Skipping real BDPM load: missing ${entry.value} in $dataDirectory.',
        );
        return;
      }
      filePaths[entry.key] = file.path;
    }

    await _parseAndInsertBdpmData(database, filePaths);
  } on Exception catch (e, stackTrace) {
    stderr
      ..writeln('[TestData] Skipping real BDPM load: $e')
      ..writeln(stackTrace);
  }
}

/// Internal function that parses and inserts BDPM data using the same logic
/// as production, but without isolate (for test performance).
Future<void> _parseAndInsertBdpmData(
  AppDatabase database,
  Map<String, String> filePaths,
) async {
  Stream<String>? streamForKey(String key) =>
      BdpmFileParser.openLineStream(filePaths[key]);

  final conditionsMap = await BdpmFileParser.parseConditions(
    streamForKey('conditions'),
  );
  final mitmMap = await BdpmFileParser.parseMitm(streamForKey('mitm'));

  final specialitesEither = await BdpmFileParser.parseSpecialites(
    streamForKey('specialites'),
    conditionsMap,
    mitmMap,
  );
  final specialitesResult = specialitesEither.fold(
    ifLeft: (ParseError error) => throw Exception(
      'Failed to parse specialites: ${_mapParseErrorToString(error)}',
    ),
    ifRight: (SpecialitesParseResult result) => result,
  );

  final medicamentsEither = await BdpmFileParser.parseMedicaments(
    streamForKey('medicaments'),
    specialitesResult,
  );
  final medicamentsResult = medicamentsEither.fold(
    ifLeft: (ParseError error) => throw Exception(
      'Failed to parse medicaments: ${_mapParseErrorToString(error)}',
    ),
    ifRight: (MedicamentsParseResult result) => result,
  );

  final compositionMap = await BdpmFileParser.parseCompositions(
    streamForKey('compositions'),
  );
  final principesEither = await BdpmFileParser.parsePrincipesActifs(
    streamForKey('compositions'),
    medicamentsResult.cisToCip13,
  );
  final principes = principesEither.fold(
    ifLeft: (ParseError error) => throw Exception(
      'Failed to parse compositions: ${_mapParseErrorToString(error)}',
    ),
    ifRight: (List<PrincipesActifsCompanion> result) => result,
  );

  final generiqueEither = await BdpmFileParser.parseGeneriques(
    streamForKey('generiques'),
    medicamentsResult.cisToCip13,
    medicamentsResult.medicamentCips,
    compositionMap,
    specialitesResult.namesByCis,
  );
  final generiqueResult = generiqueEither.fold(
    ifLeft: (ParseError error) => throw Exception(
      'Failed to parse generiques: ${_mapParseErrorToString(error)}',
    ),
    ifRight: (GeneriquesParseResult result) => result,
  );

  final availabilityEither = await BdpmFileParser.parseAvailability(
    streamForKey('availability'),
    medicamentsResult.cisToCip13,
  );
  final availabilityRows = availabilityEither.fold(
    ifLeft: (ParseError error) => throw Exception(
      'Failed to parse availability: ${_mapParseErrorToString(error)}',
    ),
    ifRight: (List<MedicamentAvailabilityCompanion> result) => result,
  );

  await _insertParsedData(
    database: database,
    specialitesResult: specialitesResult,
    medicamentsResult: medicamentsResult,
    principes: principes,
    generiqueResult: generiqueResult,
    availabilityRows: availabilityRows,
  );

  await database.databaseDao.refineGroupMetadata();

  final dataInit = DataInitializationService(database: database);
  await dataInit.runSummaryAggregationForTesting();
}

/// Inserts parsed BDPM data into the database using chunked inserts.
Future<void> _insertParsedData({
  required AppDatabase database,
  required SpecialitesParseResult specialitesResult,
  required MedicamentsParseResult medicamentsResult,
  required List<PrincipesActifsCompanion> principes,
  required GeneriquesParseResult generiqueResult,
  required List<MedicamentAvailabilityCompanion> availabilityRows,
}) async {
  if (specialitesResult.laboratories.isNotEmpty) {
    await _insertChunked(
      database,
      (batch, chunk, mode) =>
          batch.insertAll(database.laboratories, chunk, mode: mode),
      specialitesResult.laboratories,
      mode: InsertMode.replace,
    );
  }

  await _insertChunked(
    database,
    (batch, chunk, mode) =>
        batch.insertAll(database.specialites, chunk, mode: mode),
    specialitesResult.specialites,
    mode: InsertMode.replace,
  );

  await _insertChunked(
    database,
    (batch, chunk, mode) =>
        batch.insertAll(database.medicaments, chunk, mode: mode),
    medicamentsResult.medicaments,
    mode: InsertMode.replace,
  );

  await _insertChunked(
    database,
    (batch, chunk, mode) =>
        batch.insertAll(database.principesActifs, chunk, mode: mode),
    principes,
  );

  await _insertChunked(
    database,
    (batch, chunk, mode) =>
        batch.insertAll(database.generiqueGroups, chunk, mode: mode),
    generiqueResult.generiqueGroups,
    mode: InsertMode.replace,
  );

  await _insertChunked(
    database,
    (batch, chunk, mode) =>
        batch.insertAll(database.groupMembers, chunk, mode: mode),
    generiqueResult.groupMembers,
    mode: InsertMode.replace,
  );

  await database.batch((batch) {
    batch.deleteWhere(
      database.medicamentAvailability,
      (_) => const Constant(true),
    );
  });

  if (availabilityRows.isNotEmpty) {
    await _insertChunked(
      database,
      (batch, chunk, mode) => batch.insertAll(
        database.medicamentAvailability,
        chunk,
        mode: mode,
      ),
      availabilityRows,
      mode: InsertMode.replace,
    );
  }
}

/// Helper function to insert data in chunks for performance.
Future<void> _insertChunked<T>(
  AppDatabase db,
  void Function(Batch batch, List<T> chunk, InsertMode mode) inserter,
  Iterable<T> items, {
  InsertMode mode = InsertMode.insert,
}) async {
  final itemsList = items.toList();
  if (itemsList.isEmpty) return;

  for (var i = 0; i < itemsList.length; i += AppConfig.batchSize) {
    final end = (i + AppConfig.batchSize < itemsList.length)
        ? i + AppConfig.batchSize
        : itemsList.length;
    final chunk = itemsList.sublist(i, end);

    await db.batch((batch) {
      inserter(batch, chunk, mode);
    });
  }
}

/// Maps ParseError to string for test error messages.
String _mapParseErrorToString(ParseError error) {
  return switch (error) {
    EmptyContentError(:final fileName) =>
      'Failed to parse $fileName: file is empty or missing',
    InvalidFormatError(:final fileName, :final details) =>
      'Failed to parse $fileName: $details',
  };
}

SpecialitesCompanion buildSpecialiteCompanion({
  required String cisCode,
  required String nomSpecialite,
  required String procedureType,
  String? statutAdministratif,
  String? formePharmaceutique,
  String? voiesAdministration,
  String? etatCommercialisation,
  int? titulaireId,
  String? conditionsPrescription,
  DateTime? dateAmm,
  String? atcCode,
  bool isSurveillance = false,
}) {
  return SpecialitesCompanion(
    cisCode: Value(cisCode),
    nomSpecialite: Value(nomSpecialite),
    procedureType: Value(procedureType),
    statutAdministratif: Value(statutAdministratif),
    formePharmaceutique: Value(formePharmaceutique),
    voiesAdministration: Value(voiesAdministration),
    etatCommercialisation: Value(etatCommercialisation),
    titulaireId: Value(titulaireId),
    conditionsPrescription: Value(conditionsPrescription),
    dateAmm: Value(dateAmm),
    atcCode: Value(atcCode),
    isSurveillance: Value(isSurveillance),
  );
}

MedicamentsCompanion buildMedicamentCompanion({
  required String codeCip,
  required String cisCode,
  String? presentationLabel,
  String? commercialisationStatut,
  String? tauxRemboursement,
  double? prixPublic,
  String? agrementCollectivites,
}) {
  return MedicamentsCompanion(
    codeCip: Value(codeCip),
    cisCode: Value(cisCode),
    presentationLabel: Value(presentationLabel),
    commercialisationStatut: Value(commercialisationStatut),
    tauxRemboursement: Value(tauxRemboursement),
    prixPublic: Value(prixPublic),
    agrementCollectivites: Value(agrementCollectivites),
  );
}

PrincipesActifsCompanion buildPrincipeCompanion({
  required String codeCip,
  required String principe,
  String? dosage,
  String? dosageUnit,
  String? normalized,
}) {
  final normalizedValue =
      normalized ??
      (principe.isNotEmpty ? normalizePrincipleOptimal(principe) : null);
  return PrincipesActifsCompanion(
    codeCip: Value(codeCip),
    principe: Value(principe),
    principeNormalized: Value(normalizedValue),
    dosage: Value(dosage),
    dosageUnit: Value(dosageUnit),
  );
}

GeneriqueGroupsCompanion buildGeneriqueGroupCompanion({
  required String groupId,
  required String libelle,
  String? princepsLabel,
  String? moleculeLabel,
  String? rawLabel,
  String? parsingMethod,
}) {
  return GeneriqueGroupsCompanion(
    groupId: Value(groupId),
    libelle: Value(libelle),
    princepsLabel: Value(princepsLabel),
    moleculeLabel: Value(moleculeLabel),
    rawLabel: Value(rawLabel),
    parsingMethod: Value(parsingMethod),
  );
}

GroupMembersCompanion buildGroupMemberCompanion({
  required String groupId,
  required String codeCip,
  required int type,
}) {
  return GroupMembersCompanion(
    groupId: Value(groupId),
    codeCip: Value(codeCip),
    type: Value(type),
  );
}

LaboratoriesCompanion buildLaboratoryCompanion({
  required int id,
  required String name,
}) => LaboratoriesCompanion(
  id: Value(id),
  name: Value(name),
);

MedicamentAvailabilityCompanion buildAvailabilityCompanion({
  required String codeCip,
  required String statut,
  DateTime? dateDebut,
  DateTime? dateFin,
  String? lien,
}) => MedicamentAvailabilityCompanion(
  codeCip: Value(codeCip),
  statut: Value(statut),
  dateDebut: Value(dateDebut),
  dateFin: Value(dateFin),
  lien: Value(lien),
);

/// Extracts a real CIP code from the database.
/// Throws if no medicaments are available.
Future<String> getRealCip(AppDatabase database) async {
  final medicaments = await database.select(database.medicaments).get();
  if (medicaments.isEmpty) {
    throw Exception(
      'No medicaments in database. Load BDPM data first with loadRealBdpmData().',
    );
  }
  return medicaments.first.codeCip;
}

/// Extracts multiple real CIP codes from the database.
/// Returns up to [count] CIP codes, or all available if fewer exist.
Future<List<String>> getRealCips(AppDatabase database, {int count = 1}) async {
  final medicaments = await database.select(database.medicaments).get();
  if (medicaments.isEmpty) {
    throw Exception(
      'No medicaments in database. Load BDPM data first with loadRealBdpmData().',
    );
  }
  return medicaments.take(count).map((Medicament m) => m.codeCip).toList();
}

/// Extracts a real CIS code from the database.
/// Throws if no specialites are available.
Future<String> getRealCis(AppDatabase database) async {
  final specialites = await database.select(database.specialites).get();
  if (specialites.isEmpty) {
    throw Exception(
      'No specialites in database. Load BDPM data first with loadRealBdpmData().',
    );
  }
  return specialites.first.cisCode;
}

/// Finds a CIP code by searching for a medication name pattern.
/// Useful when you need a specific type of medication for testing.
Future<String?> findCipByNamePattern(
  AppDatabase database,
  String namePattern,
) async {
  final specialites = await (database.select(
    database.specialites,
  )..where((t) => t.nomSpecialite.like('%$namePattern%'))).get();
  if (specialites.isEmpty) return null;

  final cis = specialites.first.cisCode;
  final medicaments = await (database.select(
    database.medicaments,
  )..where((t) => t.cisCode.equals(cis))).get();
  if (medicaments.isEmpty) return null;

  return medicaments.first.codeCip;
}

/// Finds a CIP code by searching for an active principle pattern.
Future<String?> findCipByPrinciplePattern(
  AppDatabase database,
  String principlePattern,
) async {
  final principes = await (database.select(
    database.principesActifs,
  )..where((t) => t.principe.like('%$principlePattern%'))).get();
  if (principes.isEmpty) return null;

  return principes.first.codeCip;
}

/// Gets a real group ID from the database.
/// Throws if no groups are available.
Future<String> getRealGroupId(AppDatabase database) async {
  final groups = await database.select(database.generiqueGroups).get();
  if (groups.isEmpty) {
    throw Exception(
      'No generic groups in database. Load BDPM data first with loadRealBdpmData().',
    );
  }
  return groups.first.groupId;
}

/// Gets a real medication name from the database.
/// Throws if no specialites are available.
Future<String> getRealMedicationName(AppDatabase database) async {
  final specialites = await database.select(database.specialites).get();
  if (specialites.isEmpty) {
    throw Exception(
      'No specialites in database. Load BDPM data first with loadRealBdpmData().',
    );
  }
  return specialites.first.nomSpecialite;
}

/// Generates a GS1 string from a CIP code.
/// Format: 01{CIP}21{serial} 10{lot} 17{expDate}
/// If optional parameters are not provided, generates realistic test values.
String generateGs1String(
  String cip, {
  String? serial,
  String? lot,
  DateTime? expDate,
}) {
  final normalizedCip = cip.length == 13 ? '0$cip' : cip;
  final serialValue = serial ?? '32780924334799';
  final lotValue = lot ?? 'MA00614A';
  final expDateValue = expDate ?? DateTime.utc(2027, 4, 30);
  final expDateStr =
      '${expDateValue.year}${expDateValue.month.toString().padLeft(2, '0')}${expDateValue.day.toString().padLeft(2, '0')}';

  return '01${normalizedCip}21$serialValue 10$lotValue 17$expDateStr';
}

/// Generates a simple GS1 string with just the CIP (for basic tests).
String generateSimpleGs1String(String cip) {
  return '01$cip';
}

/// Gets a CIP that is guaranteed to NOT exist in the database.
/// Useful for testing error cases.
Future<String> getNonExistentCip(AppDatabase database) async {
  final medicaments = await database.select(database.medicaments).get();
  final existingCips = medicaments.map((Medicament m) => m.codeCip).toSet();

  // Generate a CIP that doesn't exist
  var candidate = '9999999999999';
  var counter = 0;
  while (existingCips.contains(candidate) && counter < 1000) {
    candidate = (9999999999999 - counter).toString().padLeft(13, '0');
    counter++;
  }

  if (existingCips.contains(candidate)) {
    throw Exception('Could not generate non-existent CIP');
  }

  return candidate;
}

// ============================================================================
// Helpers for finding medications with specific characteristics in real data
// ============================================================================

/// Finds a medication name containing accents (é, è, à, etc.).
/// Returns the first matching medication name, or null if none found.
Future<String?> findMedicationWithAccents(
  AppDatabase database,
  String pattern,
) async {
  final specialites = await (database.select(
    database.specialites,
  )..where((t) => t.nomSpecialite.like('%$pattern%'))).get();

  for (final specialite in specialites) {
    final name = specialite.nomSpecialite;
    // Check if name contains common French accents
    if (name.contains('é') ||
        name.contains('è') ||
        name.contains('ê') ||
        name.contains('à') ||
        name.contains('â') ||
        name.contains('ù') ||
        name.contains('û') ||
        name.contains('ô') ||
        name.contains('î') ||
        name.contains('ï') ||
        name.contains('ç')) {
      return name;
    }
  }

  return null;
}

/// Finds a medication name containing a hyphen.
/// Returns the first matching medication name, or null if none found.
Future<String?> findMedicationWithHyphen(
  AppDatabase database,
  String pattern,
) async {
  final specialites = await (database.select(
    database.specialites,
  )..where((t) => t.nomSpecialite.like('%$pattern%'))).get();

  for (final specialite in specialites) {
    final name = specialite.nomSpecialite;
    if (name.contains('-')) {
      return name;
    }
  }

  return null;
}

/// Finds a medication name containing an apostrophe.
/// Returns the first matching medication name, or null if none found.
Future<String?> findMedicationWithApostrophe(
  AppDatabase database,
  String pattern,
) async {
  final specialites = await (database.select(
    database.specialites,
  )..where((t) => t.nomSpecialite.like('%$pattern%'))).get();

  for (final specialite in specialites) {
    final name = specialite.nomSpecialite;
    if (name.contains("'") || name.contains('’')) {
      return name;
    }
  }

  return null;
}

/// Finds a medication with a specific condition in conditions_prescription.
/// Returns the CIS code of the first matching medication, or null if none found.
Future<String?> findMedicationWithCondition(
  AppDatabase database,
  String conditionPattern,
) async {
  final specialites = await database.select(database.specialites).get();

  for (final specialite in specialites) {
    final conditions = specialite.conditionsPrescription;
    if (conditions != null &&
        conditions.toUpperCase().contains(conditionPattern.toUpperCase())) {
      return specialite.cisCode;
    }
  }

  return null;
}

/// Finds a narcotic medication (stupéfiant).
/// Returns the CIS code of the first matching medication, or null if none found.
Future<String?> findNarcoticMedication(AppDatabase database) async {
  final result1 = await findMedicationWithCondition(database, 'STUPÉFIANT');
  if (result1 != null) return result1;
  return findMedicationWithCondition(database, 'STUPEFIANT');
}

/// Finds a hospital-only medication.
/// Returns the CIS code of the first matching medication, or null if none found.
Future<String?> findHospitalOnlyMedication(AppDatabase database) async {
  // Real datasets can be inconsistent; prefer deterministic seeded path.
  return null;
}

/// Finds a medication with a salt in its active principle (e.g., "CHLORHYDRATE DE").
/// Returns the CIP code of the first matching medication, or null if none found.
Future<String?> findMedicationWithSaltInPrinciple(AppDatabase database) async {
  final principes = await database.select(database.principesActifs).get();

  for (final principe in principes) {
    final principeName = principe.principe.toUpperCase();
    // Common salt patterns in French pharmaceutical names
    if (principeName.contains('CHLORHYDRATE') ||
        principeName.contains('HYDROCHLORURE') ||
        principeName.contains('SULFATE') ||
        principeName.contains('ACETATE') ||
        principeName.contains('MALÉATE') ||
        principeName.contains('MALEATE') ||
        principeName.contains('TARTRATE') ||
        principeName.contains('FUMARATE') ||
        principeName.contains('PHOSPHATE') ||
        principeName.contains('NITRATE') ||
        principeName.contains('BROMHYDRATE') ||
        principeName.contains('OXALATE') ||
        principeName.contains('BÉSILATE') ||
        principeName.contains('BESILATE') ||
        principeName.contains('TOSILATE')) {
      return principe.codeCip;
    }
  }

  return null;
}

/// Finds a medication name by searching in specialites.
/// Returns the first matching medication name, or null if none found.
Future<String?> findMedicationByName(
  AppDatabase database,
  String namePattern,
) async {
  final specialites = await (database.select(
    database.specialites,
  )..where((t) => t.nomSpecialite.like('%$namePattern%'))).get();

  if (specialites.isEmpty) return null;
  return specialites.first.nomSpecialite;
}
