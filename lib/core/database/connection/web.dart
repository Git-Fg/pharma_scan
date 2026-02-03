import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

/// Opens the database connection for the web platform.
QueryExecutor openConnection(LoggerService logger, {String? path}) {
  return LazyDatabase(() async {
    logger.info('Initializing Web/Wasm Database...');

    final sqlite3Uri = Uri.parse('sqlite3.wasm');
    final driftWorkerUri = Uri.parse('drift_worker.dart.js');

    // 1. Ensure reference.db is provisioned
    try {
      await WasmDatabase.open(
        databaseName: 'reference.db',
        sqlite3Uri: sqlite3Uri,
        driftWorkerUri: driftWorkerUri,
        initializeDatabase: () async {
          logger.info('Hydrating reference.db from assets...');
          final data = await rootBundle.load('assets/database/reference.db.gz');
          final bytes = data.buffer.asUint8List();
          final decoded = GZipDecoder().decodeBytes(bytes);
          return Uint8List.fromList(decoded);
        },
      );
      logger.info('reference.db provisioned.');
    } catch (e) {
      logger.warning('Failed to provision reference.db: $e');
    }

    // 2. Open the primary pharma_scan_db
    final result = await WasmDatabase.open(
      databaseName: path ?? 'pharma_scan_db',
      sqlite3Uri: sqlite3Uri,
      driftWorkerUri: driftWorkerUri,
    );

    logger.info(
        'Web database opened successfully with ${result.chosenImplementation}');
    return result.resolvedExecutor;
  });
}
