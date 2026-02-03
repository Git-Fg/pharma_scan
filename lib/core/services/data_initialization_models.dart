enum InitializationStep { idle, downloading, ready, error, updateAvailable }

class VersionCheckResult {
  final bool updateAvailable;
  final String? localDate;
  final String remoteTag;
  final String? downloadUrl;
  final bool blockedByPolicy;

  VersionCheckResult({
    required this.updateAvailable,
    this.localDate,
    required this.remoteTag,
    this.downloadUrl,
    required this.blockedByPolicy,
  });
}
