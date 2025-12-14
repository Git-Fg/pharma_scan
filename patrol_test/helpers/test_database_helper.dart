import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pharma_scan/core/config/database_config.dart';
import 'package:drift/native.dart';
import 'package:pharma_scan/core/database/database.dart';

class TestDatabaseHelper {
  /// Copie la DB de référence des assets vers le dossier documents de l'app
  /// et configure les préférences (via user.db) pour simuler une DB à jour.
  static Future<void> injectTestDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();

    // 1. Nettoyage préventif (supprimer user.db pour un état vierge, et l'ancienne ref)
    final userDbFile = File(p.join(docsDir.path, 'user.db'));
    final refDbFile =
        File(p.join(docsDir.path, DatabaseConfig.dbFilename)); // 'reference.db'

    if (await userDbFile.exists()) await userDbFile.delete();
    if (await refDbFile.exists()) await refDbFile.delete();

    // 2. Copie de l'asset vers le système de fichiers
    final byteData = await rootBundle.load('assets/test/reference.db');
    final buffer = byteData.buffer;

    await refDbFile.writeAsBytes(
      buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      flush: true,
    );

    // 3. Configuration des préférences via AppSettings dans user.db
    // On utilise AppDatabase pour initialiser correctement la structure si nécessaire
    final db = AppDatabase.forTesting(NativeDatabase(userDbFile));

    try {
      // Force creation of tables (including app_settings)
      await db.customSelect('SELECT 1').get();

      // Utilisation du DAO pour écrire les flags de version
      await db.appSettingsDao.setBdpmVersion('test-version-local');
      await db.appSettingsDao
          .setLastSyncEpoch(DateTime.now().millisecondsSinceEpoch);
    } finally {
      await db.close();
    }

    print(
        '✅ Test Database injected at: ${refDbFile.path} with settings in ${userDbFile.path}');
  }
}