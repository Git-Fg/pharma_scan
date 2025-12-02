// tool/verify_db.dart
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:pharma_scan/core/database/database.dart';

/// Simple database health check script.
/// Verifies that the database is correctly populated and FTS5 search works.
///
/// Usage: dart run tool/verify_db.dart [path/to/medicaments.db] [SEARCH_TERM]
/// If no path is provided the script looks for `tool/data/medicaments.db`
/// and then `./medicaments.db`.
Future<void> main(List<String> args) async {
  print('🔍 PharmaScan Database Health Check\n');

  final resolvedPath = await _resolveDbPath(args);
  if (resolvedPath == null) {
    print('❌ Database path not provided and no medicaments.db in this folder.');
    print(
      '   Usage: dart run tool/verify_db.dart /path/to/medicaments.db [SEARCH_TERM]',
    );
    exit(1);
  }

  final dbFile = File(resolvedPath);

  // Check if database exists
  if (!await dbFile.exists()) {
    print('❌ Database file not found: $resolvedPath');
    print(
      '   Provide a valid path or run the app first to initialize the database.',
    );
    exit(1);
  }

  // Print file size
  final fileSize = await dbFile.length();
  final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(2);
  print('📁 Database file: $resolvedPath');
  print('   Size: $fileSizeMB MB\n');

  // Open database
  final database = AppDatabase.forTesting(
    NativeDatabase(dbFile, setup: configureAppSQLite),
  );

  try {
    // Action 1: Count rows in medicament_summary
    print('1️⃣  Checking medicament_summary table...');
    final summaryCount = await database
        .customSelect('SELECT COUNT(*) as count FROM medicament_summary')
        .getSingle();
    final count = summaryCount.read<int>('count');
    print('   ✅ medicament_summary contains $count records');

    if (count == 0) {
      print('   ⚠️  WARNING: Database appears empty!');
      print('   Run the app to initialize data.');
    } else {
      // Show sample records
      final samples = await (database.select(
        database.medicamentSummary,
      )..limit(3)).get();
      print('   Sample records:');
      for (final record in samples) {
        print('     - ${record.nomCanonique} (${record.cisCode})');
      }
    }

    print('');

    // Action 2: Test FTS5 search
    print('2️⃣  Testing FTS5 search_index...');
    final queryArg = args.length >= 2 ? args[1] : null;
    final searchQuery = queryArg ?? 'DOLIPRANE';
    print('   Query: "$searchQuery"');

    // Check if search_index has data
    final indexCount = await database
        .customSelect('SELECT COUNT(*) as count FROM search_index')
        .getSingle();
    final indexCountValue = indexCount.read<int>('count');
    print('   ✅ search_index contains $indexCountValue records');

    if (indexCountValue == 0) {
      print('   ⚠️  WARNING: FTS5 index is empty!');
      print('   Run the app to populate the search index.');
    } else {
      // Run FTS5 query
      final searchResults = await database
          .customSelect(
            '''
            SELECT 
              ms.cis_code,
              ms.nom_canonique,
              ms.princeps_brand_name,
              si.rank
            FROM medicament_summary ms
            INNER JOIN search_index si ON ms.cis_code = si.cis_code
            WHERE search_index MATCH ?
            ORDER BY si.rank
            LIMIT 5
            ''',
            variables: [Variable.withString(searchQuery)],
            readsFrom: {database.medicamentSummary},
          )
          .get();

      if (searchResults.isEmpty) {
        print('   ⚠️  No results found for "$searchQuery"');
        print(
          '   Try a different search term (e.g., "PARACETAMOL", "AMOXICILLINE")',
        );
      } else {
        print('   ✅ Found ${searchResults.length} results:');
        for (final result in searchResults) {
          final canonicalName = result.read<String>('nom_canonique');
          final brandName = result.read<String?>('princeps_brand_name');
          final cisCode = result.read<String>('cis_code');
          final displayName = brandName ?? canonicalName;
          print('     - $displayName ($cisCode)');
        }
      }
    }

    print('');

    // Action 3: Summary
    print('3️⃣  Summary:');
    if (count > 0 && indexCountValue > 0) {
      print('   ✅ Database is healthy and ready to use!');
    } else {
      print('   ⚠️  Database needs initialization.');
      print('   Launch the app to download and populate data.');
    }
  } finally {
    await database.close();
  }
}

Future<String?> _resolveDbPath(List<String> args) async {
  if (args.isNotEmpty) {
    return p.normalize(args.first);
  }

  final projectDir = Directory.current.path;
  final toolDataPath = p.join(projectDir, 'tool', 'data', 'medicaments.db');
  if (await File(toolDataPath).exists()) {
    return toolDataPath;
  }

  final localPath = p.join(projectDir, 'medicaments.db');
  if (await File(localPath).exists()) {
    return localPath;
  }

  return null;
}
