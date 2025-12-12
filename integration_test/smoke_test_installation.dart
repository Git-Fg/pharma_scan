import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUpAll(() async {
    // Copy the minimal test database to the documents directory
    await _setupMinimalTestDatabase();

    // Initialize the database with the copied file
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(documentsDir.path, 'pharma_scan.db');
    final nativeDB = NativeDatabase(dbPath);

    db = AppDatabase.forTesting(nativeDB);
  });

  tearDownAll(() async {
    await db.close();
  });

  group('Smoke Test - Installation & Initialization', () {
    testWidgets(
      'should load data from pre-prepared database',
      (WidgetTester tester) async {
        // Test that data is already present in medicament_summary
        final summaries = await (db.select(db.medicamentSummary)..limit(10)).get();

        expect(
          summaries,
          isNotEmpty,
          reason: 'MedicamentSummary should be populated from pre-prepared database',
        );

        // Verify we have the expected test data
        expect(summaries.length, 4, reason: 'Should have 4 test medications');

        // Check that Doliprane is present
        final doliprane = summaries.firstWhere(
          (s) => s.nomCanonique.contains('Doliprane'),
          orElse: () => throw Exception('Doliprane not found in test data'),
        );
        expect(doliprane.isPrinceps, isTrue);
        expect(doliprane.representativeCip, '3400930012345');

        // Check that Paracetamol Biogaran is present as a generic
        final biogaran = summaries.firstWhere(
          (s) => s.nomCanonique.contains('Biogaran'),
          orElse: () => throw Exception('Biogaran not found in test data'),
        );
        expect(biogaran.isPrinceps, isFalse);
        expect(biogaran.princepsDeReference, contains('Doliprane'));

        // Verify all entries have required fields
        for (final summary in summaries) {
          expect(summary.cisCode, isNotEmpty);
          expect(summary.nomCanonique, isNotEmpty);
          expect(summary.princepsDeReference, isNotEmpty);
          expect(summary.isPrinceps, isA<bool>());
        }
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    testWidgets(
      'should have FTS5 search_index populated with triggers',
      (WidgetTester tester) async {
        // Test that search index is populated via triggers
        final searchResults = await db.customSelect(
          'SELECT COUNT(*) as count FROM search_index',
        ).getSingle();

        final count = searchResults.read<int>('count');

        expect(
          count,
          equals(4),
          reason: 'FTS5 search_index should have 4 entries (one for each medicament_summary)',
        );

        // Test that search index contains expected data
        final dolipraneSearch = await db.customSelect(
          "SELECT * FROM search_index WHERE brand_name LIKE '%Doliprane%' LIMIT 1",
        ).getSingle();

        final cisCode = dolipraneSearch.read<String>('cis_code');
        expect(cisCode, 'CIS_DOLIPRANE_500');
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    testWidgets(
      'should be able to query medications with filters',
      (WidgetTester tester) async {
        // Test filtering by OTC status
        final otcMeds = await (db.select(db.medicamentSummary)
              ..where((tbl) => tbl.isOtc.equals(true)))
            .get();

        expect(otcMeds.length, 4, reason: 'All test medications should be OTC');

        // Test filtering by princeps status
        final princepsMeds = await (db.select(db.medicamentSummary)
              ..where((tbl) => tbl.isPrinceps.equals(true)))
            .get();

        expect(
          princepsMeds.length,
          3,
          reason: 'Should have 3 princeps medications',
        );

        // Test that cluster information is preserved
        final paracetamolCluster = await (db.select(db.medicamentSummary)
              ..where((tbl) => tbl.clusterId.equals('PARACETAMOL')))
            .get();

        expect(
          paracetamolCluster.length,
          2,
          reason: 'Should have 2 medications in PARACETAMOL cluster',
        );
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );
  });
}

/// Copies the minimal test database to the app's documents directory.
/// This simulates downloading a database from the server in production.
Future<void> _setupMinimalTestDatabase() async {
  // Get the application documents directory
  final documentsDir = await getApplicationDocumentsDirectory();
  final targetPath = p.join(documentsDir.path, 'pharma_scan.db');

  // If the database already exists, delete it to ensure a clean state
  final targetFile = File(targetPath);
  if (await targetFile.exists()) {
    await targetFile.delete();
  }

  // Copy the minimal test database from assets
  final sourcePath = p.join(
    Directory.current.path,
    'integration_test',
    'assets',
    'minimal_test.db',
  );
  final sourceFile = File(sourcePath);

  if (!await sourceFile.exists()) {
    throw Exception(
      'Minimal test database not found at $sourcePath. '
      'Please run the create_test_db.dart script first.',
    );
  }

  // Copy the database
  await sourceFile.copy(targetPath);
  print('Copied minimal test database to: $targetPath');
}