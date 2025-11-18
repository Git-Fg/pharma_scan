// lib/core/services/data_initialization_service.dart
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/config/data_sources.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/parser/medicament_grammar.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataInitializationService {
  DataInitializationService({
    required SharedPreferences sharedPreferences,
    DatabaseService? databaseService,
    String? cacheDirectory,
  }) : _sharedPreferences = sharedPreferences,
       dbService = databaseService ?? sl<DatabaseService>(),
       _globalCacheDir = cacheDirectory ?? _resolveDefaultCacheDir();

  static const _initializationKey = 'bdpm_data_version';
  static const _currentDataVersion = '2025-01-20-rc1';

  final SharedPreferences _sharedPreferences;
  final DatabaseService dbService;
  final String? _globalCacheDir;

  Future<void> initializeDatabase({bool forceRefresh = false}) async {
    final persistedVersion = _sharedPreferences.getString(_initializationKey);
    final hasExistingData = await dbService.hasExistingData();

    if (!forceRefresh &&
        persistedVersion == _currentDataVersion &&
        hasExistingData) {
      return;
    }

    await _performFullRefresh();

    await _sharedPreferences.setString(_initializationKey, _currentDataVersion);
  }

  Future<void> _performFullRefresh() async {
    final filePaths = await _downloadAllFiles();
    final parsedMap = await compute(_parseDataInBackground, filePaths);
    final parsedData = _ParsedDataBundle.fromMap(parsedMap);

    developer.log(
      'Parsed ${parsedData.medicaments.length} medicaments, '
      '${parsedData.principes.length} principles, and '
      '${parsedData.groupMembers.length} group members.',
      name: 'DataInitService',
    );

    await dbService.clearDatabase();
    await dbService.insertBatchData(
      specialites: parsedData.specialites,
      medicaments: parsedData.medicaments,
      principes: parsedData.principes,
      generiqueGroups: parsedData.generiqueGroups,
      groupMembers: parsedData.groupMembers,
    );

    // Phase 2: Aggregate data for MedicamentSummary table
    await _aggregateDataForSummary();

    await _sharedPreferences.setString(_initializationKey, _currentDataVersion);
  }

  Future<Map<String, String>> _downloadAllFiles() async {
    final results = <String, String>{};
    for (final entry in DataSources.files.entries) {
      results[entry.key] = await _getFilePath(entry.key, entry.value);
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
        developer.log(
          'Using cached BDPM file $filename from $cacheDir',
          name: 'DataInitService',
        );
        return cacheFile.path;
      }
    }

    // Download and cache the file if not already cached
    final bytes = await _fetchFileBytesWithCache(
      storageKey: storageKey,
      url: url,
      filename: filename,
    );

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
    required String storageKey,
    required String url,
    required String filename,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    final remoteMetadata = await _fetchRemoteMetadata(url);

    final cachedBytes = await _reuseCacheIfUnchanged(
      storageKey: storageKey,
      file: file,
      metadata: remoteMetadata,
    );
    if (cachedBytes != null) return cachedBytes;

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        await _persistRemoteHeaders(
          storageKey: storageKey,
          remoteMetadata: remoteMetadata,
          responseHeaders: response.headers,
        );
        return response.bodyBytes;
      }
    } catch (_) {
      // Fallback handled below
    }

    if (await file.exists()) {
      developer.log(
        'Falling back to cached file $filename after download failure.',
        name: 'DataInitService',
      );
      return file.readAsBytes();
    }

    throw Exception('Failed to download $filename');
  }

  Future<_RemoteMetadata> _fetchRemoteMetadata(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      if (response.statusCode == 200) {
        return _RemoteMetadata(
          etag: response.headers['etag'],
          lastModified: response.headers['last-modified'],
        );
      }
    } catch (_) {
      // Ignore HEAD failures - we'll fallback to direct download.
    }
    return const _RemoteMetadata();
  }

  Future<List<int>?> _reuseCacheIfUnchanged({
    required String storageKey,
    required File file,
    required _RemoteMetadata metadata,
  }) async {
    if (!metadata.hasHeaders || !await file.exists()) {
      return null;
    }
    final storedEtag = _sharedPreferences.getString(_etagKey(storageKey));
    final storedLastModified = _sharedPreferences.getString(
      _lastModifiedKey(storageKey),
    );

    final hasMatchingEtag =
        metadata.etag != null && metadata.etag == storedEtag;
    final hasMatchingLastModified =
        metadata.lastModified != null &&
        metadata.lastModified == storedLastModified;

    if (hasMatchingEtag || hasMatchingLastModified) {
      developer.log(
        'Using cached file for $storageKey (no upstream changes).',
        name: 'DataInitService',
      );
      return file.readAsBytes();
    }

    return null;
  }

  Future<void> _persistRemoteHeaders({
    required String storageKey,
    required _RemoteMetadata remoteMetadata,
    required Map<String, String> responseHeaders,
  }) async {
    final etag = remoteMetadata.etag ?? responseHeaders['etag'];
    final lastModified =
        remoteMetadata.lastModified ?? responseHeaders['last-modified'];

    if (etag != null && etag.isNotEmpty) {
      await _sharedPreferences.setString(_etagKey(storageKey), etag);
    }
    if (lastModified != null && lastModified.isNotEmpty) {
      await _sharedPreferences.setString(
        _lastModifiedKey(storageKey),
        lastModified,
      );
    }
  }

  String _etagKey(String storageKey) => 'bdpm_cache_etag_$storageKey';

  String _lastModifiedKey(String storageKey) =>
      'bdpm_cache_last_modified_$storageKey';

  @visibleForTesting
  Future<void> runSummaryAggregationForTesting() => _aggregateDataForSummary();

  // Phase 2: Aggregate data for MedicamentSummary table
  Future<void> _aggregateDataForSummary() async {
    developer.log(
      'Starting data aggregation for MedicamentSummary table.',
      name: 'DataInitService',
    );

    // 1. Fetch Raw Data (Main Isolate)
    // Fetch groups with their members and specialite details
    // WHY: We fetch as Map<String, dynamic> to be sendable to the isolate
    final groupsQuery = await dbService.database.customSelect('''
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
    // Fetch in chunks if too many variables, but for now we assume it fits or we could chunk it.
    // Given the volume, we should probably fetch ALL principles for relevant CIPs.
    // To avoid huge IN clauses, we can fetch all principles that are linked to ANY group member.
    // Or better: fetch all principles where code_cip IN (SELECT code_cip FROM group_members)

    final principesQuery = await dbService.database.customSelect('''
      SELECT 
        pa.code_cip,
        pa.principe
      FROM principes_actifs pa
      INNER JOIN group_members gm ON pa.code_cip = gm.code_cip
      ORDER BY pa.code_cip, pa.principe
    ''').get();

    final principesData = principesQuery.map((row) => row.data).toList();

    final dto = _AggregationDataDTO(
      groups: groupsData,
      principes: principesData,
    );

    // 2. Process in Background (Isolate)
    final summaryRecords = await compute(_computeSummaryRecords, dto);

    // 3. Batch Insert (Main Isolate)
    await dbService.database.batch((batch) {
      batch.insertAll(
        dbService.database.medicamentSummary,
        summaryRecords.map(
          (record) => MedicamentSummaryCompanion.insert(
            cisCode: record['cis_code'] as String,
            nomCanonique: record['nom_canonique'] as String,
            isPrinceps: record['is_princeps'] == 1,
            groupId: Value(record['group_id'] as String?),
            principesActifsCommuns:
                record['principes_actifs_communs'] as String,
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

    developer.log(
      'Aggregated ${summaryRecords.length} records into MedicamentSummary table using Drift batch.',
      name: 'DataInitService',
    );
  }
}

class _AggregationDataDTO {
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> principes;

  _AggregationDataDTO({required this.groups, required this.principes});
}

List<Map<String, dynamic>> _computeSummaryRecords(_AggregationDataDTO dto) {
  final medicamentParser = MedicamentParser();

  // Group principles by medication
  final principesByCip = <String, List<String>>{};
  for (final row in dto.principes) {
    final cip = row['code_cip'] as String;
    final principe = row['principe'] as String;
    principesByCip.putIfAbsent(cip, () => []).add(principe);
  }

  // Group medications by group and calculate common principles
  final groupsData = <String, _GroupData>{};
  for (final row in dto.groups) {
    final groupId = row['group_id'] as String;
    final type = row['type'] as int;
    final codeCip = row['code_cip'] as String;
    final nomSpecialite = row['nom_specialite'] as String;

    final groupData = groupsData.putIfAbsent(
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
  for (final row in dto.groups) {
    final groupId = row['group_id'] as String;
    rowsByGroupId.putIfAbsent(groupId, () => []).add(row);
  }

  // Calculate common principles for each group (principles present in ALL medications)
  for (final groupData in groupsData.values) {
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
  for (final groupData in groupsData.values) {
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
        .map((principe) => sanitizeActivePrinciple(principe))
        .where((principe) => principe.isNotEmpty)
        .toList();

    // We need to implement _buildClusterKey and _normalizeClusterSegment inside this function or make them static/top-level
    // Since they are private instance methods in the original class, we'll duplicate them as local helpers or make them static.
    // For simplicity, I'll implement the logic here or use static helpers if I can.
    // I'll add _staticBuildClusterKey helper.
    groupData.clusterKey = _staticBuildClusterKey(
      groupData.princepsBrandName,
      groupData.sanitizedPrincipes,
    );
  }

  // Prepare batch insert for MedicamentSummary table
  final summaryRecords = <Map<String, dynamic>>[];
  for (final row in dto.groups) {
    final groupId = row['group_id'] as String;
    final type = row['type'] as int;
    final cisCode = row['cis_code'] as String;
    final nomSpecialite = row['nom_specialite'] as String;
    final formePharmaceutique = row['forme_pharmaceutique'] as String?;
    final procedureType = row['procedure_type'] as String?;
    final titulaire = row['titulaire'] as String?;
    final conditionsPrescription = row['conditions_prescription'] as String?;

    final groupData = groupsData[groupId]!;
    final sanitizedPrincipes = groupData.sanitizedPrincipes;
    final princepsDeReference = groupData.princepsDeReference;
    // Pass the official form and lab as hints to the parser
    final parsedName = medicamentParser.parse(
      nomSpecialite,
      officialForm: formePharmaceutique,
      officialLab: titulaire,
    );

    // Sanitize active principles
    final principesJson = jsonEncode(sanitizedPrincipes);

    // Create canonical name (remove dosage and form)
    final nomCanonique =
        parsedName.baseName ?? deriveGroupTitleFromName(nomSpecialite);
    final brandName = groupData.princepsBrandName ?? princepsDeReference;
    final clusterKey =
        groupData.clusterKey ??
        _staticBuildClusterKey(brandName, sanitizedPrincipes);

    summaryRecords.add({
      'cis_code': cisCode,
      'nom_canonique': nomCanonique,
      'is_princeps': type == 0 ? 1 : 0,
      'group_id': groupId,
      'principes_actifs_communs': principesJson,
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

String _staticBuildClusterKey(
  String? brandName,
  List<String> sanitizedPrincipes,
) {
  final normalizedBrand = _staticNormalizeClusterSegment(
    brandName ?? 'UNKNOWN',
  );
  final normalizedPrincipes =
      sanitizedPrincipes.isEmpty
            ? <String>['NO_PA']
            : sanitizedPrincipes.map(_staticNormalizeClusterSegment).toList()
        ..sort();
  return '${normalizedBrand}__${normalizedPrincipes.join('_')}';
}

String _staticNormalizeClusterSegment(String value) {
  final upper = value.toUpperCase();
  var cleaned = upper.replaceAll(RegExp(r'[^A-Z0-9]+'), '_');
  cleaned = cleaned.replaceAll(RegExp(r'_+'), '_');
  cleaned = cleaned.replaceAll(RegExp(r'^_+|_+$'), '').trim();
  return cleaned.isEmpty ? 'UNK' : cleaned;
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

  return {
    'specialites': specialitesResult.specialites,
    'medicaments': medicamentsResult.medicaments,
    'principes': principes,
    'generiqueGroups': generiqueResult.generiqueGroups,
    'groupMembers': generiqueResult.groupMembers,
  };
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

class _RemoteMetadata {
  const _RemoteMetadata({this.etag, this.lastModified});

  final String? etag;
  final String? lastModified;

  bool get hasHeaders =>
      (etag != null && etag!.isNotEmpty) ||
      (lastModified != null && lastModified!.isNotEmpty);
}
