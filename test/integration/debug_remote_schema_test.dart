import 'dart:io';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pharma_scan/core/config/database_config.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:sqlite3/sqlite3.dart' as raw_sql;

void main() {
  // URL construite manuellement ou importée de votre config
  const downloadUrl =
      'https://github.com/${DatabaseConfig.repoOwner}/${DatabaseConfig.repoName}/releases/latest/download/${DatabaseConfig.compressedDbFilename}';

  test('FORENSIC: Download, Inspect and Validate Remote DB', () async {
    developer.log('⬇️ 1. Downloading DB from: $downloadUrl');

    // 1. Téléchargement
    final dio = Dio();
    final response = await dio.get<List<int>>(
      downloadUrl,
      options: Options(responseType: ResponseType.bytes),
    );

    final compressedBytes = response.data!;
    developer.log(
        '📦 Downloaded size: [32m${(compressedBytes.length / 1024 / 1024).toStringAsFixed(2)} MB[0m');

    // 2. Décompression
    developer.log('gzip... Decompressing...');
    final bytes = GZipCodec().decode(compressedBytes);
    developer.log(
        '📂 Decompressed size: [32m${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB[0m');

    // 3. Écriture fichier temporaire
    final tempDir = Directory.systemTemp.createTempSync('db_debug_');
    final dbFile = File('${tempDir.path}/debug_reference.db');
    await dbFile.writeAsBytes(bytes);
    developer.log('💾 Saved to: ${dbFile.path}');

    // ---------------------------------------------------------
    // ANALYSE 1 : Inspection brute via sqlite3 (La vérité terrain)
    // ---------------------------------------------------------
    developer.log('\n--- 🕵️ RAW SQLITE INSPECTION ---');
    final rawDb = raw_sql.sqlite3.open(dbFile.path);

    // Lister les tables
    final tables =
        rawDb.select("SELECT name FROM sqlite_master WHERE type='table'");
    final tableNames = tables.map((r) => r['name'] as String).toList();
    developer.log('Found tables: $tableNames');

    if (!tableNames.contains('medicament_summary')) {
      fail('CRITICAL: Table `medicament_summary` is missing in the remote DB!');
    }

    // Inspecter les colonnes de medicament_summary
    final columnsInfo = rawDb.select("PRAGMA table_info(medicament_summary)");
    developer.log('\nColumns in `medicament_summary`:');
    for (final row in columnsInfo) {
      developer.log(' - ${row['name']} (${row['type']})');
    }
    rawDb.dispose();

    // ---------------------------------------------------------
    // ANALYSE 2 : Test d'ouverture via Drift (Votre Code)
    // ---------------------------------------------------------
    developer.log('\n--- 🎯 DRIFT COMPATIBILITY TEST ---');

    // On ouvre une instance Drift sur ce fichier spécifique
    final database = AppDatabase.forTesting(
      NativeDatabase(dbFile),
    );

    try {
      // On tente une requête simple
      final count = await database
          .customSelect('SELECT count(*) as c FROM medicament_summary')
          .getSingle();

      developer.log('✅ SUCCESS: Drift connected and read data.');
      developer.log('   Row count: ${count.read<int>('c')}');

      // On tente votre check d'intégrité
      await database.checkDatabaseIntegrity();
      developer.log('✅ checkDatabaseIntegrity() passed.');
    } catch (e, s) {
      developer.log('❌ FAILURE: Drift failed to read the DB.');
      developer.log('Error: $e');
      developer.log('Stack: $s');
      fail('Drift incompatibility detected');
    } finally {
      await database.close();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
