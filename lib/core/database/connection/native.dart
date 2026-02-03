import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:archive/archive.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

QueryExecutor openConnection(LoggerService logger, {String? path}) {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();

    // 1. Define paths for BOTH databases
    final userDbFile =
        path != null ? File(path) : File(p.join(dbFolder.path, 'user.db'));
    final referenceDbFile = File(p.join(dbFolder.path, 'reference.db'));

    // Check for hydration
    if (!await referenceDbFile.exists()) {
      logger.info('Reference DB missing, hydrating from assets...');
      try {
        final data = await rootBundle.load('assets/database/reference.db.gz');
        final bytes = data.buffer.asUint8List();
        final decoded = GZipDecoder().decodeBytes(bytes);
        await referenceDbFile.writeAsBytes(decoded, flush: true);
        logger.info('Hydration complete.');
      } catch (e, stack) {
        logger.error('Failed to hydrate DB', e, stack);
        // If hydration fails, we probably shouldn't proceed with an empty DB
        throw Exception('Failed to hydrate reference database: $e');
      }
    }

    // 2. Open USER.DB as the primary connection
    return NativeDatabase(
      userDbFile,
      setup: (database) {
        // 3. Attach REFERENCE.DB dynamically when connection opens
        // 'reference_db' is the alias we will use in queries if needed,
        // though Drift handles this transparently for known tables.
        database.execute(
            "ATTACH DATABASE '${referenceDbFile.path}' AS reference_db");
      },
    );
  });
}
