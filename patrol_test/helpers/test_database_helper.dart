import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pharma_scan/core/config/database_config.dart';
import 'package:drift/native.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

class TestDatabaseHelper {
  /// Copie la DB de référence des assets vers le dossier documents de l'app
  /// et configure les préférences (via user.db) pour simuler une DB à jour.
  static Future<void> injectTestDatabase() async {
    Directory docsDir;
    try {
      docsDir = await getApplicationDocumentsDirectory();
    } on MissingPluginException catch (_) {
      // Running in a pure Dart/unit test environment without the Flutter
      // engine. Fall back to a temp directory to avoid MissingPluginException.
      docsDir = await Directory.systemTemp.createTemp('pharma_scan_test_');
    } on PlatformException catch (_) {
      // Another platform-related error; also fallback to temp directory.
      docsDir = await Directory.systemTemp.createTemp('pharma_scan_test_');
    }

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
    final db =
        AppDatabase.forTesting(NativeDatabase(userDbFile), LoggerService());

    try {
      // Force creation of tables (including app_settings)
      await db.customSelect('SELECT 1').get();

      // Utilisation du DAO pour écrire les flags de version
      await db.appSettingsDao.setBdpmVersion('test-version-local');
      await db.appSettingsDao
          .setLastSyncEpoch(DateTime.now().millisecondsSinceEpoch);

      // --- Additional test preferences previously provided by
      // MockPreferencesHelper.configureForTesting() ---
      // These keys ensure the running app reads the mocked state from
      // the `app_settings` table during Patrol E2E tests.
      await db.appSettingsDao.setSetting('onboarding_completed', true);
      await db.appSettingsDao.setSetting('initial_tutorial_shown', true);
      await db.appSettingsDao.setSetting('terms_accepted', true);
      await db.appSettingsDao.setSetting('privacy_policy_accepted', true);
      await db.appSettingsDao.setSetting('user_profile_setup', true);

      // Permissions
      await db.appSettingsDao.setSetting('camera_permissions_granted', true);
      await db.appSettingsDao.setSetting('storage_permissions_granted', true);

      // App flags
      await db.appSettingsDao.setSetting('is_first_launch', false);
      await db.appSettingsDao.setSetting('analytics_enabled', false);
      await db.appSettingsDao.setSetting('crash_reporting_enabled', false);
      await db.appSettingsDao.setSetting('auto_update_enabled', false);
      await db.appSettingsDao.setSetting('show_tutorial_hints', false);
      await db.appSettingsDao.setSetting('default_scan_mode', 'analysis');

      // User preferences
      await db.appSettingsDao.setSetting('preferred_language', 'fr');
      await db.appSettingsDao.setSetting('dark_mode', false);
      await db.appSettingsDao.setSetting('haptic_feedback', true);
      await db.appSettingsDao.setSetting('sound_enabled', true);
    } finally {
      await db.close();
    }

    debugPrint(
        '✅ Test Database injected at: ${refDbFile.path} with settings in ${userDbFile.path}');
  }
}
