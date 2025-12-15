import 'dart:io';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

/// Crée une instance réelle de la DB, mais en mémoire (rapide + volatile)
/// Utile pour tester la logique métier complexe sans dépendre de fichiers réels
///
/// [useRealReferenceDatabase] : Si true, attache la vraie DB de référence (assets/test/reference.db)
/// au lieu de laisser le schéma vide ou de devoir le créer manuellement.
AppDatabase createTestDatabase({
  void Function(dynamic)? setup,
  bool useRealReferenceDatabase = false,
}) {
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      logStatements: false,
      setup: (db) {
        if (useRealReferenceDatabase) {
          // 1. Locate the reference DB file
          // In 'flutter test', the working directory is usually the project root.
          final referenceDbPath = 'assets/test/reference.db';
          final referenceFile = File(referenceDbPath);

          if (!referenceFile.existsSync()) {
            throw Exception(
                'Reference DB not found at $referenceDbPath. Run scripts/dump_schema.sh or check path.');
          }

          // 2. Copy the reference DB to a temporary file for isolation
          // This allows tests to write/modify the attached DB without affecting the asset
          // or other tests running in parallel (if they used the same file).
          final tempDir =
              Directory.systemTemp.createTempSync('pharma_scan_test_ref_');
          final tempDbFile = File(p.join(tempDir.path, 'reference_copy.db'));
          referenceFile.copySync(tempDbFile.path);

          // 3. Attach the temporary copy
          final absolutePath = tempDbFile.absolute.path;
          db.execute("ATTACH DATABASE '$absolutePath' AS reference_db");

          // Ensure cleanup (best effort, OS usually handles /tmp cleanup,
          // but strictly we can't easily hook into DB close from here for file deletion
          // without changing the return type or wrapping AppDatabase)
        }

        // Run user-provided setup if any (e.g. for other attachments or PRAGMAs)
        setup?.call(db);
      },
    ), // Activez logStatements pour débugger le SQL
    LoggerService(),
  );
}
