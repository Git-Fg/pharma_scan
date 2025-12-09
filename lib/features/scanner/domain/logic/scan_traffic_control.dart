class ScanTrafficControl {
  ScanTrafficControl({
    Duration cooldownDuration = const Duration(seconds: 2),
    Duration cleanupThreshold = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _cooldownDuration = cooldownDuration,
       _cleanupThreshold = cleanupThreshold,
       _now = now ?? DateTime.now;

  final Map<String, DateTime> _scanCooldowns = {};
  final Set<String> _processingCips = {};
  final Duration _cooldownDuration;
  final Duration _cleanupThreshold;
  final DateTime Function() _now;

  bool shouldProcess(String key, {bool force = false}) {
    final now = _now();
    _cleanupExpired(now);
    if (force) {
      _record(key, now);
      return true;
    }
    if (_processingCips.contains(key)) {
      return false;
    }
    if (_isCooldownActive(key, now)) {
      return false;
    }
    _record(key, now);
    return true;
  }

  void markProcessed(String key) {
    _processingCips.remove(key);
  }

  bool isCooldownActive(String key) => _isCooldownActive(key, _now());

  void reset() {
    _scanCooldowns.clear();
    _processingCips.clear();
  }

  void _record(String key, DateTime now) {
    _scanCooldowns[key] = now;
    _processingCips.add(key);
  }

  bool _isCooldownActive(String key, DateTime now) {
    final lastScan = _scanCooldowns[key];
    if (lastScan == null) return false;
    return now.difference(lastScan) < _cooldownDuration;
  }

  void _cleanupExpired(DateTime now) {
    _scanCooldowns.removeWhere(
      (_, lastSeen) => now.difference(lastSeen) > _cleanupThreshold,
    );
  }
}
