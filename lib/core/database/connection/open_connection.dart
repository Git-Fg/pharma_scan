import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/config/database_config.dart';

/// Ouvre la base de données située dans le dossier Documents de l'app.
/// Si le fichier n'existe pas encore (pas téléchargé), cela renverra une erreur gérée plus haut.
LazyDatabase openDownloadedDatabase() {
  return LazyDatabase(() async {
    // 1. Récupérer le dossier sécurisé de l'application
    final dbFolder = await getApplicationDocumentsDirectory();

    // 2. Cibler le fichier spécifique (nom défini par votre logique de téléchargement)
    final file = File(p.join(dbFolder.path, DatabaseConfig.dbFilename));

    // 3. (Sécurité) Vérifier si le fichier existe avant d'essayer de l'ouvrir
    if (!await file.exists()) {
      throw const FileSystemException(
        'Base de données introuvable. Veuillez lancer la synchronisation.',
        DatabaseConfig.dbFilename,
      );
    }

    // 4. Créer l'exécuteur en tâche de fond (thread séparé pour ne pas bloquer l'UI)
    return NativeDatabase.createInBackground(file);
  });
}
