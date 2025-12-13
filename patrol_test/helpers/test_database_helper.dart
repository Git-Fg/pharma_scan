import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pharma_scan/core/config/database_config.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestDatabaseHelper {
  /// Copie la DB de référence des assets vers le dossier documents de l'app
  /// et configure les préférences pour simuler une DB à jour.
  static Future<void> injectTestDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();

    // 1. Nettoyage préventif (supprimer user.db pour un état vierge, et l'ancienne ref)
    final userDbFile = File(p.join(docsDir.path, 'user.db'));
    final refDbFile = File(p.join(docsDir.path, DatabaseConfig.dbFilename)); // 'reference.db'

    if (await userDbFile.exists()) await userDbFile.delete();
    if (await refDbFile.exists()) await refDbFile.delete();

    // 2. Copie de l'asset vers le système de fichiers
    // Note: Assurez-vous que le chemin correspond à votre pubspec
    final byteData = await rootBundle.load('assets/test/reference.db');
    final buffer = byteData.buffer;

    await refDbFile.writeAsBytes(
      buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      flush: true,
    );

    // 3. Configuration des préférences
    // On doit dire à l'app que la DB est initialisée et correspond à une version valide
    // pour éviter qu'elle tente un téléchargement au démarrage.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.bdpmVersion, 'test-version-local');
    await prefs.setInt(PrefKeys.lastSyncEpoch, DateTime.now().millisecondsSinceEpoch);

    print('✅ Test Database injected at: ${refDbFile.path}');
  }
}