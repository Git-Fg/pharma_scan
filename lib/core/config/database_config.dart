/// Configuration pour le système d'auto-mise à jour de la base de données
class DatabaseConfig {
  DatabaseConfig._();

  /// Repository GitHub (owner/repo)
  static const String repoOwner = 'Git-Fg';
  static const String repoName = 'pharma_scan';

  /// Nom du fichier de base de données
  static const String dbFilename = 'reference.db';

  /// Nom du fichier compressé
  static const String compressedDbFilename = 'reference.db.gz';

  /// Clé pour stocker la version de la DB dans sourceHashes
  static const String prefKeyLastVersion = 'db_version_tag';

  /// URL de l'API GitHub pour les releases
  static String get githubReleasesUrl =>
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
}
