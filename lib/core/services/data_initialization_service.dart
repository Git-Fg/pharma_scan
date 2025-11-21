// lib/core/services/data_initialization_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/config/data_sources.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/drift_database_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/parser/medicament_grammar.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

typedef SummaryComputationArgs = ({String dbPath, String tempPath});

class DataInitializationService {
  DataInitializationService({
    required DriftDatabaseService databaseService,
    String? cacheDirectory,
    FileDownloadService? fileDownloadService,
  }) : _databaseService = databaseService,
       _globalCacheDir = cacheDirectory ?? _resolveDefaultCacheDir(),
       _fileDownloadService = fileDownloadService ?? FileDownloadService();

  static const _currentDataVersion = '2025-01-20-rc1';

  final DriftDatabaseService
  _databaseService; // Changed from DatabaseService and renamed
  final String? _globalCacheDir;
  final FileDownloadService _fileDownloadService;

  Future<void> initializeDatabase({bool forceRefresh = false}) async {
    final persistedVersion = await _databaseService.getBdpmVersion();
    final hasExistingData = await _databaseService
        .hasExistingData(); // Using _databaseService

    LoggerService.info(
      '[DataInit] initializeDatabase(forceRefresh: $forceRefresh, '
      'persisted: $persistedVersion, current: $_currentDataVersion, '
      'hasData: $hasExistingData)',
    );

    if (!forceRefresh &&
        persistedVersion == _currentDataVersion &&
        hasExistingData) {
      LoggerService.info(
        '[DataInit] Initialization skipped: cache matches current version.',
      );
      return;
    }

    LoggerService.info(
      '[DataInit] Initialization required (force: $forceRefresh). '
      'Starting full refresh…',
    );
    await _performFullRefresh();
  }

  Future<void> _performFullRefresh() async {
    LoggerService.info(
      '[DataInit] Starting full BDPM refresh (download + parse + aggregate).',
    );
    final filePaths = await _downloadAllFiles();
    await _parseAndInsertData(filePaths);

    await _databaseService.updateBdpmVersion(_currentDataVersion);
    await _markSyncAsFresh();
  }

  Future<void> applyUpdate(Map<String, File> tempFiles) async {
    LoggerService.info('[DataInit] Applying updates from SyncService...');
    LoggerService.info(
      '[DataInit] Received ${tempFiles.length} files from SyncService.',
    );

    final filePaths = <String, String>{};
    final cacheDir = _globalCacheDir;
    final appDir = await getApplicationDocumentsDirectory();

    for (final entry in tempFiles.entries) {
      final key = entry.key;
      final tempFile = entry.value;
      final sourceUrl = DataSources.files[key];
      if (sourceUrl == null) continue;

      final filename = _extractFilenameFromUrl(sourceUrl);
      final destinationPath = cacheDir != null
          ? p.join(cacheDir, filename)
          : p.join(appDir.path, filename);
      final destinationFile = File(destinationPath);

      if (!await destinationFile.parent.exists()) {
        await destinationFile.parent.create(recursive: true);
      }
      await tempFile.copy(destinationFile.path);
      filePaths[key] = destinationFile.path;
    }

    await _parseAndInsertData(filePaths);

    await _databaseService.updateBdpmVersion(_currentDataVersion);
    await _markSyncAsFresh();
  }

  Future<void> _parseAndInsertData(Map<String, String> filePaths) async {
    LoggerService.info(
      '[DataInit] Parsing BDPM files: ${filePaths.keys.join(', ')}',
    );
    final parsedMap = await compute(_parseDataInBackground, filePaths);
    final parsedData = _ParsedDataBundle.fromMap(parsedMap);

    LoggerService.info(
      '[DataInit] Parsed ${parsedData.medicaments.length} medicaments, '
      '${parsedData.principes.length} principles, and '
      '${parsedData.groupMembers.length} group members.',
    );

    await _databaseService.clearDatabase();
    await _databaseService.insertBatchData(
      specialites: parsedData.specialites,
      medicaments: parsedData.medicaments,
      principes: parsedData.principes,
      generiqueGroups: parsedData.generiqueGroups,
      groupMembers: parsedData.groupMembers,
    );

    LoggerService.info(
      '[DataInit] Persisted parsed data. Aggregating summary table next.',
    );
    // Phase 2: Aggregate data for MedicamentSummary table
    await _aggregateDataForSummary();
  }

  Future<void> _markSyncAsFresh() async {
    // WHY: SyncService reads this timestamp to skip redundant checks right
    // after a successful initialization run.
    await _databaseService.updateSyncTimestamp(
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<Map<String, String>> _downloadAllFiles() async {
    final results = <String, String>{};
    for (final entry in DataSources.files.entries) {
      LoggerService.info(
        '[DataInit] Downloading ${entry.key} from ${entry.value}',
      );
      results[entry.key] = await _getFilePath(entry.key, entry.value);
      LoggerService.info(
        '[DataInit] Downloaded ${entry.key} to ${results[entry.key]}',
      );
    }
    return results;
  }

  Future<String> _getFilePath(String storageKey, String url) async {
    final filename = _extractFilenameFromUrl(url);
    final cacheDir = _globalCacheDir;

    // Ensure cache directory exists
    if (cacheDir != null) {
      final cacheFile = File(p.join(cacheDir, filename));
      if (await cacheFile.exists()) {
        LoggerService.info(
          '[DataInit] Using cached BDPM file $filename from $cacheDir',
        );
        return cacheFile.path;
      }
    }

    // Download and cache the file if not already cached
    final bytes = await _fetchFileBytesWithCache(url: url, filename: filename);

    // Write to global cache
    if (cacheDir != null) {
      await _writeGlobalCache(filename, bytes);
      return File(p.join(cacheDir, filename)).path;
    }

    // Fallback to application documents directory
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  String _extractFilenameFromUrl(String url) {
    final uri = Uri.parse(url);
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'bdpm.txt';
  }

  static String? _resolveDefaultCacheDir() {
    final env = Platform.environment['PHARMA_BDPM_CACHE'];
    if (env != null && env.isNotEmpty) {
      final dir = Directory(env);
      if (dir.existsSync()) return dir.path;
    }
    final defaultDir = Directory(p.join('.dart_tool', 'bdpm_cache'));
    if (defaultDir.existsSync()) {
      return defaultDir.path;
    }
    return null;
  }

  Future<void> _writeGlobalCache(String filename, List<int> bytes) async {
    final cacheDir = _globalCacheDir;
    if (cacheDir == null) return;
    final file = File(p.join(cacheDir, filename));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<List<int>> _fetchFileBytesWithCache({
    required String url,
    required String filename,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheFile = File('${directory.path}/$filename');

    // WHY: Use centralized FileDownloader service for consistent error handling,
    // timeouts, and Talker logging across all file downloads.
    return _fileDownloadService.downloadToBytesWithCacheFallback(
      url: url,
      cacheFile: cacheFile,
    );
  }

  @visibleForTesting
  Future<void> runSummaryAggregationForTesting({
    bool useBackgroundIsolate = false,
  }) => _aggregateDataForSummary(useBackgroundIsolate: useBackgroundIsolate);

  // WHY: Get the database file path to pass to isolate
  // The database is stored in application documents directory
  Future<String> _getDatabasePath() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    return p.join(dbFolder.path, 'medicaments.db');
  }

  // Phase 2: Aggregate data for MedicamentSummary table
  Future<void> _aggregateDataForSummary({
    bool useBackgroundIsolate = true,
  }) async {
    LoggerService.info(
      '[DataInit] Starting data aggregation for MedicamentSummary table.',
    );

    // 1. Get database path and fetch standalone rows (Main Isolate)
    // WHY: Standalone rows are processed in main isolate since they're a smaller dataset
    final dbPath = await _getDatabasePath();
    final tempPath = (await getTemporaryDirectory()).path;

    final standaloneRows = await _databaseService.database
        .getStandaloneSpecialites()
        .get();
    LoggerService.info(
      '[DataInit] Identified ${standaloneRows.length} standalone spécialités sans groupe.',
    );

    // Get principes for standalone rows only (smaller subset)
    final standaloneCips = <String>{};
    for (final row in standaloneRows) {
      final codeCipValue = row.codeCip;
      if (codeCipValue != null && codeCipValue.isNotEmpty) {
        standaloneCips.add(codeCipValue);
      }
    }

    final principesByCipForStandalone = <String, List<String>>{};
    if (standaloneCips.isNotEmpty) {
      final principesQuery = await _databaseService.database
          .getPrincipesForCips(standaloneCips.toList())
          .get();

      for (final row in principesQuery) {
        final codeCip = row.codeCip;
        final principe = row.principe;
        if (codeCip == null ||
            codeCip.isEmpty ||
            principe == null ||
            principe.isEmpty) {
          continue;
        }
        principesByCipForStandalone
            .putIfAbsent(codeCip, () => <String>[])
            .add(principe);
      }
    }

    // 2. Process groups in Background (Isolate)
    // WHY: Pass only the database path string (~1KB) instead of large data structures (~50-100MB)
    final args = (dbPath: dbPath, tempPath: tempPath);

    final summaryRecords = useBackgroundIsolate
        ? await compute(_computeSummaryRecords, args)
        : await _computeSummaryRecords(args);

    final standaloneSummaries = _buildStandaloneSummaryRecords(
      standaloneRows,
      principesByCipForStandalone,
    );
    summaryRecords.addAll(standaloneSummaries);

    // 3. Batch Insert (Main Isolate)
    await _databaseService.database.batch((batch) {
      batch.insertAll(
        _databaseService.database.medicamentSummary,
        summaryRecords.map(
          (record) => MedicamentSummaryCompanion.insert(
            cisCode: record['cis_code'] as String,
            nomCanonique: record['nom_canonique'] as String,
            isPrinceps: record['is_princeps'] == 1,
            groupId: Value(record['group_id'] as String?),
            principesActifsCommuns:
                record['principes_actifs_communs'] as List<String>,
            princepsDeReference: record['princeps_de_reference'] as String,
            formePharmaceutique: Value(
              record['forme_pharmaceutique'] as String?,
            ),
            princepsBrandName: record['princeps_brand_name'] as String,
            clusterKey: record['cluster_key'] as String,
            procedureType: Value(record['procedure_type'] as String?),
            titulaire: Value(record['titulaire'] as String?),
            conditionsPrescription: Value(
              record['conditions_prescription'] as String?,
            ),
          ),
        ),
        mode: InsertMode.replace,
      );
    });

    final standaloneCount = standaloneSummaries.length;

    LoggerService.db(
      'Aggregated ${summaryRecords.length} records into MedicamentSummary table using Drift batch '
      '(standalones: $standaloneCount).',
    );
  }
}

// WHY: Static function to open database in isolate
// Must be top-level or static to be sendable to isolate
Future<AppDatabase> _openDatabaseInIsolate(
  String dbPath,
  String tempPath,
) async {
  final file = File(dbPath);

  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }

  sqlite3.tempDirectory = tempPath;

  final database = NativeDatabase(file);
  return AppDatabase.forTesting(database);
}

Future<List<Map<String, dynamic>>> _computeSummaryRecords(
  SummaryComputationArgs args,
) async {
  // WHY: Open database connection in isolate to avoid passing large data structures
  final db = await _openDatabaseInIsolate(args.dbPath, args.tempPath);
  final medicamentParser = MedicamentParser();

  // Fetch groups with their members and specialite details
  final groupsQuery = await db.customSelect('''
    SELECT 
      gg.group_id,
      gg.libelle,
      gm.code_cip,
      gm.type,
      s.cis_code,
      s.nom_specialite,
      s.forme_pharmaceutique,
      s.procedure_type,
      s.titulaire,
      s.conditions_prescription
    FROM generique_groups gg
    INNER JOIN group_members gm ON gg.group_id = gm.group_id
    INNER JOIN medicaments m ON gm.code_cip = m.code_cip
    INNER JOIN specialites s ON m.cis_code = s.cis_code
    ORDER BY gg.group_id, gm.type, s.nom_specialite
  ''').get();

  final groupsData = groupsQuery.map((row) => row.data).toList();

  // Get all active principles for each medication
  // WHY: Fetch all principles for relevant CIPs. Drift 2.24.0+ handles large sets internally.
  final principesQuery = await db.customSelect('''
    SELECT 
      code_cip,
      principe
    FROM principes_actifs
    ORDER BY code_cip, principe
  ''').get();

  final principesByCip = <String, List<String>>{};
  for (final row in principesQuery) {
    final data = row.data;
    final codeCipValue = data['code_cip'];
    if (codeCipValue == null) continue;
    final codeCip = codeCipValue.toString();
    final principe = data['principe'] as String?;
    if (principe == null || principe.isEmpty) continue;
    principesByCip.putIfAbsent(codeCip, () => <String>[]).add(principe);
  }

  // Group medications by group and calculate common principles
  final groupsDataMap = <String, _GroupData>{};
  for (final row in groupsData) {
    final groupId = row['group_id'] as String;
    final type = row['type'] as int;
    final codeCip = row['code_cip'] as String;
    final nomSpecialite = row['nom_specialite'] as String;

    final groupData = groupsDataMap.putIfAbsent(
      groupId,
      () => _GroupData(
        groupId: groupId,
        princepsNames: [],
        genericNames: [],
        allPrincipes: <String>{},
      ),
    );

    if (type == 0) {
      // Princeps
      groupData.princepsNames.add(nomSpecialite);
    } else {
      // Generic
      groupData.genericNames.add(nomSpecialite);
    }

    // Add all principles for this medication to group's principles set
    final principes = principesByCip[codeCip] ?? [];
    groupData.allPrincipes.addAll(principes);
  }

  // WHY: Pre-group rows by groupId to avoid O(N^2) lookups in the loop below
  final rowsByGroupId = <String, List<Map<String, dynamic>>>{};
  for (final row in groupsData) {
    final groupId = row['group_id'] as String;
    rowsByGroupId.putIfAbsent(groupId, () => []).add(row);
  }

  // Calculate common principles for each group (principles present in ALL medications)
  for (final groupData in groupsDataMap.values) {
    // WHY: Use the pre-grouped map instead of iterating list with .where()
    final groupRows = rowsByGroupId[groupData.groupId] ?? const [];

    if (groupRows.isNotEmpty) {
      final firstCip = groupRows.first['code_cip'] as String;
      var commonPrincipes = Set<String>.from(principesByCip[firstCip] ?? []);

      for (int i = 1; i < groupRows.length; i++) {
        final currentCip = groupRows[i]['code_cip'] as String;
        final currentPrincipes = principesByCip[currentCip] ?? [];
        commonPrincipes = commonPrincipes.intersection(
          Set.from(currentPrincipes),
        );

        if (commonPrincipes.isEmpty) break;
      }

      groupData.commonPrincipes = commonPrincipes.toList();
    }
  }

  // Calculate reference princeps name for each group
  for (final groupData in groupsDataMap.values) {
    groupData.princepsDeReference = findCommonPrincepsName(
      groupData.princepsNames,
    );
    final parsedPrincepsBases = groupData.princepsNames
        .map(medicamentParser.parse)
        .map((parsed) => parsed.baseName)
        .whereType<String>()
        .toList();
    final derivedBrand = parsedPrincepsBases.isNotEmpty
        ? findCommonPrincepsName(parsedPrincepsBases)
        : groupData.princepsDeReference;
    if (derivedBrand != 'N/A') {
      groupData.princepsBrandName = derivedBrand;
    } else {
      groupData.princepsBrandName = groupData.princepsDeReference;
    }
    groupData.sanitizedPrincipes = groupData.commonPrincipes
        .map(sanitizeActivePrinciple)
        .where((principe) => principe.isNotEmpty)
        .toList();

    groupData.clusterKey = buildClusterKey(
      groupData.princepsBrandName,
      groupData.sanitizedPrincipes,
    );
  }

  // Prepare batch insert for MedicamentSummary table
  final summaryRecords = <Map<String, dynamic>>[];
  for (final row in groupsData) {
    final groupId = row['group_id'] as String;
    final type = row['type'] as int;
    final cisCode = row['cis_code'] as String;
    final nomSpecialite = row['nom_specialite'] as String;
    final formePharmaceutique = row['forme_pharmaceutique'] as String?;
    final procedureType = row['procedure_type'] as String?;
    final titulaire = row['titulaire'] as String?;
    final conditionsPrescription = row['conditions_prescription'] as String?;

    final groupData = groupsDataMap[groupId]!;
    final sanitizedPrincipes = groupData.sanitizedPrincipes;
    final princepsDeReference = groupData.princepsDeReference;
    // Pass the official form and lab as hints to the parser
    final parsedName = medicamentParser.parse(
      nomSpecialite,
      officialForm: formePharmaceutique,
      officialLab: titulaire,
    );

    // Create canonical name (remove dosage and form)
    final nomCanonique =
        parsedName.baseName ?? deriveGroupTitleFromName(nomSpecialite);
    final brandName = groupData.princepsBrandName ?? princepsDeReference;
    final clusterKey =
        groupData.clusterKey ?? buildClusterKey(brandName, sanitizedPrincipes);

    summaryRecords.add({
      'cis_code': cisCode,
      'nom_canonique': nomCanonique,
      'is_princeps': type == 0 ? 1 : 0,
      'group_id': groupId,
      'principes_actifs_communs': sanitizedPrincipes,
      'princeps_de_reference': princepsDeReference,
      'forme_pharmaceutique': formePharmaceutique,
      'princeps_brand_name': brandName,
      'cluster_key': clusterKey,
      'procedure_type': procedureType,
      'titulaire': titulaire,
      'conditions_prescription': conditionsPrescription,
    });
  }

  return summaryRecords;
}

List<Map<String, dynamic>> _buildStandaloneSummaryRecords(
  List<GetStandaloneSpecialitesResult> standaloneRows,
  Map<String, List<String>> principesByCip,
) {
  if (standaloneRows.isEmpty) return const [];
  final medicamentParser = MedicamentParser();
  final records = <Map<String, dynamic>>[];

  for (final row in standaloneRows) {
    final cisCode = row.cisCode;
    final codeCip = row.codeCip;
    final nomSpecialite = row.nomSpecialite ?? '';

    if (cisCode == null ||
        codeCip == null ||
        codeCip.isEmpty ||
        nomSpecialite.isEmpty) {
      continue;
    }

    final formePharmaceutique = row.formePharmaceutique;
    final procedureType = row.procedureType;
    final titulaire = row.titulaire;
    final conditionsPrescription = row.conditionsPrescription;

    final principes = principesByCip[codeCip] ?? const <String>[];
    final sanitizedPrincipes = principes
        .map(sanitizeActivePrinciple)
        .where((principe) => principe.isNotEmpty)
        .toList();
    final parsedName = medicamentParser.parse(
      nomSpecialite,
      officialForm: formePharmaceutique,
      officialLab: titulaire,
    );
    final nomCanonique =
        parsedName.baseName ?? deriveGroupTitleFromName(nomSpecialite);
    final brandName = nomCanonique.isNotEmpty
        ? nomCanonique
        : deriveGroupTitleFromName(nomSpecialite);
    final clusterKey = buildClusterKey(brandName, sanitizedPrincipes);

    records.add({
      'cis_code': cisCode,
      'nom_canonique': nomCanonique,
      'is_princeps': 1,
      'group_id': null,
      'principes_actifs_communs': sanitizedPrincipes,
      'princeps_de_reference': brandName,
      'forme_pharmaceutique': formePharmaceutique,
      'princeps_brand_name': brandName,
      'cluster_key': clusterKey,
      'procedure_type': procedureType,
      'titulaire': titulaire,
      'conditions_prescription': conditionsPrescription,
    });
  }

  return records;
}

// Helper class for group data aggregation
class _GroupData {
  final String groupId;
  final List<String> princepsNames;
  final List<String> genericNames;
  final Set<String> allPrincipes;
  List<String> commonPrincipes = [];
  late String princepsDeReference;
  List<String> sanitizedPrincipes = [];
  String? princepsBrandName;
  String? clusterKey;

  _GroupData({
    required this.groupId,
    required this.princepsNames,
    required this.genericNames,
    required this.allPrincipes,
  });
}

Future<Map<String, dynamic>> _parseDataInBackground(
  Map<String, String> filePaths,
) async {
  // Helper to read file inside isolate
  String? readFileInIsolate(String path) {
    final file = File(path);
    if (!file.existsSync()) return null;
    final bytes = file.readAsBytesSync();
    return _decodeContent(bytes);
  }

  final conditionsMap = _parseConditions(
    readFileInIsolate(filePaths['conditions'] ?? ''),
  );
  final specialitesResult = _parseSpecialites(
    readFileInIsolate(filePaths['specialites'] ?? ''),
    conditionsMap,
  );

  final medicamentsResult = _parseMedicaments(
    readFileInIsolate(filePaths['medicaments'] ?? ''),
    specialitesResult,
  );

  final principes = _parseCompositions(
    readFileInIsolate(filePaths['compositions'] ?? ''),
    medicamentsResult.cisToCip13,
  );

  final generiqueResult = _parseGeneriques(
    readFileInIsolate(filePaths['generiques'] ?? ''),
    medicamentsResult.cisToCip13,
    medicamentsResult.medicamentCips,
  );
  final payload = {
    'specialites': specialitesResult.specialites,
    'medicaments': medicamentsResult.medicaments,
    'principes': principes,
    'generiqueGroups': generiqueResult.generiqueGroups,
    'groupMembers': generiqueResult.groupMembers,
  };
  _assertSendable(payload);
  return payload;
}

_SpecialitesParseResult _parseSpecialites(
  String? content,
  Map<String, String> conditionsByCis,
) {
  final specialites = <Map<String, dynamic>>[];
  final namesByCis = <String, String>{};
  final seenCis = <String>{};

  if (content == null) {
    return (specialites: specialites, namesByCis: namesByCis, seenCis: seenCis);
  }

  for (final line in content.split('\n')) {
    final parts = line.split('\t');
    if (parts.length >= 11) {
      final cis = parts[0].trim();
      final nom = parts[1].trim();
      final forme = parts[2].trim();
      final procedure = parts[5].trim();
      final commercialisation = parts[6].trim();
      final titulaire = parts[10].trim();

      if (cis.isNotEmpty && nom.isNotEmpty && seenCis.add(cis)) {
        final record = {
          'cis_code': cis,
          'nom_specialite': nom,
          'procedure_type': procedure,
          'forme_pharmaceutique': forme,
          'etat_commercialisation': commercialisation,
          'titulaire': titulaire,
          'conditions_prescription': conditionsByCis[cis],
        };
        specialites.add(record);
        namesByCis[cis] = nom;
      }
    }
  }

  return (specialites: specialites, namesByCis: namesByCis, seenCis: seenCis);
}

_MedicamentsParseResult _parseMedicaments(
  String? content,
  _SpecialitesParseResult specialitesResult,
) {
  final cisToCip13 = <String, List<String>>{};
  final medicaments = <Map<String, dynamic>>[];
  final medicamentCips = <String>{};
  final seenCis = specialitesResult.seenCis;
  final namesByCis = specialitesResult.namesByCis;

  if (content == null) {
    return (
      medicaments: medicaments,
      cisToCip13: cisToCip13,
      medicamentCips: medicamentCips,
    );
  }

  for (final line in content.split('\n')) {
    final parts = line.split('\t');
    if (parts.length >= 7) {
      final cis = parts[0].trim();
      final cip13 = parts[6].trim();
      final correctName = namesByCis[cis];

      if (cis.isNotEmpty &&
          cip13.isNotEmpty &&
          correctName != null &&
          seenCis.contains(cis)) {
        cisToCip13.putIfAbsent(cis, () => []).add(cip13);

        if (medicamentCips.add(cip13)) {
          medicaments.add({'code_cip': cip13, 'cis_code': cis});
        }
      }
    }
  }

  return (
    medicaments: medicaments,
    cisToCip13: cisToCip13,
    medicamentCips: medicamentCips,
  );
}

List<Map<String, dynamic>> _parseCompositions(
  String? content,
  Map<String, List<String>> cisToCip13,
) {
  final principes = <Map<String, dynamic>>[];

  if (content == null) return principes;

  for (final line in content.split('\n')) {
    final parts = line.split('\t');
    if (parts.length >= 8 && parts[6].trim() == 'SA') {
      final cis = parts[0].trim();
      final principe = parts[3].trim();
      final dosageStr = parts[4].trim();

      final cip13s = cisToCip13[cis];
      if (cip13s != null && principe.isNotEmpty) {
        Decimal? dosageValue;
        String? dosageUnit;

        if (dosageStr.isNotEmpty) {
          final dosageParts = dosageStr.split(' ');
          if (dosageParts.isNotEmpty) {
            final normalizedValue = dosageParts[0].replaceAll(',', '.');
            dosageValue = Decimal.tryParse(normalizedValue);
            if (dosageParts.length > 1) {
              dosageUnit = dosageParts.sublist(1).join(' ');
            }
          }
        }

        for (final cip13 in cip13s) {
          principes.add({
            'code_cip': cip13,
            'principe': principe,
            'dosage': dosageValue?.toString(),
            'dosage_unit': dosageUnit,
          });
        }
      }
    }
  }

  return principes;
}

_GeneriquesParseResult _parseGeneriques(
  String? content,
  Map<String, List<String>> cisToCip13,
  Set<String> medicamentCips,
) {
  final generiqueGroups = <Map<String, dynamic>>[];
  final groupMembers = <Map<String, dynamic>>[];
  final seenGroups = <String>{};

  if (content == null) {
    return (generiqueGroups: generiqueGroups, groupMembers: groupMembers);
  }

  for (final line in content.split('\n')) {
    final parts = line.split('\t');
    if (parts.length >= 5) {
      final groupId = parts[0].trim();
      final libelle = parts[1].trim();
      final cis = parts[2].trim();
      final type = int.tryParse(parts[3].trim());
      final cip13s = cisToCip13[cis];
      final isPrinceps = type == 0;
      final isGeneric = type == 1 || type == 2 || type == 4;

      if (cip13s != null && (isPrinceps || isGeneric)) {
        if (seenGroups.add(groupId)) {
          generiqueGroups.add({'group_id': groupId, 'libelle': libelle});
        }

        for (final cip13 in cip13s) {
          if (medicamentCips.contains(cip13)) {
            groupMembers.add({
              'code_cip': cip13,
              'group_id': groupId,
              'type': isPrinceps ? 0 : 1,
            });
          }
        }
      }
    }
  }

  return (generiqueGroups: generiqueGroups, groupMembers: groupMembers);
}

Map<String, String> _parseConditions(String? content) {
  final conditions = <String, String>{};

  if (content == null) return conditions;

  for (final line in content.split('\n')) {
    final parts = line.split('\t');
    if (parts.length >= 2) {
      final cis = parts[0].trim();
      final condition = parts[1].trim();
      if (cis.isNotEmpty && condition.isNotEmpty) {
        conditions[cis] = condition;
      }
    }
  }

  return conditions;
}

String? _decodeContent(List<int>? bytes) {
  if (bytes == null) return null;
  try {
    return latin1.decode(bytes);
  } catch (_) {
    return utf8.decode(bytes, allowMalformed: true);
  }
}

void _assertSendable(Object? value) {
  if (value == null ||
      value is num ||
      value is bool ||
      value is String ||
      value is Uint8List ||
      value is Int32List ||
      value is Int64List ||
      value is Float64List) {
    return;
  }
  if (value is List) {
    for (final item in value) {
      _assertSendable(item);
    }
    return;
  }
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw ArgumentError(
          'Sendable check failed: map key must be a String but was ${key.runtimeType}',
        );
      }
      _assertSendable(entry.value);
    }
    return;
  }

  throw ArgumentError('Sendable check failed for ${value.runtimeType}: $value');
}

typedef _SpecialitesParseResult = ({
  List<Map<String, dynamic>> specialites,
  Map<String, String> namesByCis,
  Set<String> seenCis,
});

typedef _MedicamentsParseResult = ({
  List<Map<String, dynamic>> medicaments,
  Map<String, List<String>> cisToCip13,
  Set<String> medicamentCips,
});

typedef _GeneriquesParseResult = ({
  List<Map<String, dynamic>> generiqueGroups,
  List<Map<String, dynamic>> groupMembers,
});

class _ParsedDataBundle {
  _ParsedDataBundle({
    required this.specialites,
    required this.medicaments,
    required this.principes,
    required this.generiqueGroups,
    required this.groupMembers,
  });

  factory _ParsedDataBundle.fromMap(Map<String, dynamic> map) {
    return _ParsedDataBundle(
      specialites: (map['specialites'] as List).cast<Map<String, dynamic>>(),
      medicaments: (map['medicaments'] as List).cast<Map<String, dynamic>>(),
      principes: (map['principes'] as List).cast<Map<String, dynamic>>(),
      generiqueGroups: (map['generiqueGroups'] as List)
          .cast<Map<String, dynamic>>(),
      groupMembers: (map['groupMembers'] as List).cast<Map<String, dynamic>>(),
    );
  }

  final List<Map<String, dynamic>> specialites;
  final List<Map<String, dynamic>> medicaments;
  final List<Map<String, dynamic>> principes;
  final List<Map<String, dynamic>> generiqueGroups;
  final List<Map<String, dynamic>> groupMembers;
}
