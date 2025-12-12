import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pharma_scan/core/config/database_config.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

/// Service pour gérer la mise à jour automatique de la base de données depuis GitHub Releases
class DatabaseUpdaterService {
  DatabaseUpdaterService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(minutes: 5),
            ),
          );

  final Dio _dio;

  /// Vérifie et applique la mise à jour si nécessaire
  ///
  /// Retourne `true` si une mise à jour a été effectuée, `false` sinon.
  /// En cas d'erreur, retourne `false` (le système de fallback prendra le relais).
  Future<bool> checkForUpdate(AppDatabase database) async {
    try {
      LoggerService.info('[DatabaseUpdater] Vérification des mises à jour...');

      // 1. Récupérer la dernière release GitHub
      final response = await _dio.get<Map<String, dynamic>>(
        DatabaseConfig.githubReleasesUrl,
        options: Options(
          responseType: ResponseType.json,
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        LoggerService.warning(
          '[DatabaseUpdater] Erreur API GitHub: ${response.statusCode}',
        );
        return false;
      }

      final json = response.data!;
      final latestTag = json['tag_name'] as String;

      // Trouver l'URL de téléchargement de l'asset reference.db.gz
      final assets = json['assets'] as List<dynamic>;
      final asset = assets.firstWhere(
        (a) =>
            (a as Map<String, dynamic>)['name'] ==
            DatabaseConfig.compressedDbFilename,
        orElse: () => null,
      );

      if (asset == null) {
        LoggerService.warning(
          '[DatabaseUpdater] Asset ${DatabaseConfig.compressedDbFilename} non trouvé dans la release',
        );
        return false;
      }

      final downloadUrl =
          (asset as Map<String, dynamic>)['browser_download_url'] as String;

      // 2. Comparer avec la version locale (stockée dans sourceHashes)
      final currentTag = await database.settingsDao.getDbVersionTag();

      if (currentTag == latestTag) {
        LoggerService.info(
          '[DatabaseUpdater] Base de données à jour ($currentTag)',
        );
        return false;
      }

      LoggerService.info(
        '[DatabaseUpdater] Nouvelle version trouvée : $latestTag (Actuelle : $currentTag)',
      );

      // 3. Télécharger et Remplacer
      await _performUpdate(downloadUrl, database);

      // 4. Sauvegarder la nouvelle version
      await database.settingsDao.setDbVersionTag(latestTag);

      LoggerService.info('[DatabaseUpdater] Mise à jour effectuée avec succès');
      return true; // Mise à jour effectuée
    } on TimeoutException catch (e) {
      LoggerService.warning(
        '[DatabaseUpdater] Timeout lors de la vérification: $e',
      );
      return false;
    } catch (e, stackTrace) {
      LoggerService.error(
        '[DatabaseUpdater] Erreur lors de la mise à jour',
        e,
        stackTrace,
      );
      return false;
    }
  }

  Future<void> _performUpdate(String url, AppDatabase database) async {
    LoggerService.info('[DatabaseUpdater] Téléchargement de la mise à jour...');

    // Télécharger le fichier compressé
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.statusCode != 200 || response.data == null) {
      throw Exception('Échec téléchargement: ${response.statusCode}');
    }

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, DatabaseConfig.dbFilename);
    final tempGzPath = p.join(
      dir.path,
      '${DatabaseConfig.compressedDbFilename}_temp',
    );
    final tempDbPath = p.join(dir.path, '${DatabaseConfig.dbFilename}_temp');

    try {
      // Écrire le fichier compressé temporaire
      final tempGzFile = File(tempGzPath);
      await tempGzFile.writeAsBytes(response.data!);

      LoggerService.info(
        '[DatabaseUpdater] Décompression de la base de données...',
      );

      // Décompresser le fichier avec GZipCodec natif de Dart
      final compressedBytes = await tempGzFile.readAsBytes();
      final gzipCodec = GZipCodec();
      final decompressedBytes = gzipCodec.decode(compressedBytes);
      final tempDbFile = File(tempDbPath);
      await tempDbFile.writeAsBytes(decompressedBytes);

      LoggerService.info(
        '[DatabaseUpdater] Remplacement de la base de données...',
      );

      // CRITIQUE : Fermer la connexion SQLite avant de toucher au fichier
      // Drift gère automatiquement la vérification de l'état de la connexion
      await database.close();
      LoggerService.info('[DatabaseUpdater] Connexion fermée');

      // Nettoyer les fichiers temporaires SQLite (WAL/SHM)
      await _cleanupWalFiles(dbPath);

      // Remplacer l'ancien fichier par le nouveau de manière atomique
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      await tempDbFile.rename(dbPath);

      LoggerService.info(
        '[DatabaseUpdater] Base de données mise à jour avec succès',
      );

      // Note : L'application devra rouvrir la connexion DB après cet appel.
      // Cela sera géré par le système de réinitialisation de Drift.
    } finally {
      // Nettoyer les fichiers temporaires
      try {
        final tempGzFile = File(tempGzPath);
        if (await tempGzFile.exists()) {
          await tempGzFile.delete();
        }
        final tempDbFile = File(tempDbPath);
        if (await tempDbFile.exists() && tempDbFile.path != dbPath) {
          await tempDbFile.delete();
        }
      } catch (e) {
        LoggerService.warning(
          '[DatabaseUpdater] Erreur lors du nettoyage des fichiers temporaires: $e',
        );
      }
    }
  }

  /// Nettoie les fichiers WAL et SHM associés à la base de données
  Future<void> _cleanupWalFiles(String dbPath) async {
    final walFile = File('$dbPath-wal');
    final shmFile = File('$dbPath-shm');

    try {
      if (await walFile.exists()) {
        await walFile.delete();
        LoggerService.info('[DatabaseUpdater] Fichier WAL supprimé');
      }
      if (await shmFile.exists()) {
        await shmFile.delete();
        LoggerService.info('[DatabaseUpdater] Fichier SHM supprimé');
      }
    } catch (e) {
      LoggerService.warning(
        '[DatabaseUpdater] Erreur lors de la suppression des fichiers WAL/SHM: $e',
      );
      // Ne pas faire échouer la mise à jour pour ça
    }
  }
}
