/// Modèle de données pour les settings (compatible avec l'ancienne API)
class AppSetting {
  AppSetting({
    required this.themeMode,
    required this.updateFrequency,
    required this.sourceHashes, required this.sourceDates, required this.hapticFeedbackEnabled, required this.preferredSorting, required this.scanHistoryLimit, this.bdpmVersion,
    this.lastSyncEpoch,
  });

  final String themeMode;
  final String updateFrequency;
  final String? bdpmVersion;
  final int? lastSyncEpoch;
  final String sourceHashes;
  final String sourceDates;
  final bool hapticFeedbackEnabled;
  final String preferredSorting;
  final int scanHistoryLimit;
}
