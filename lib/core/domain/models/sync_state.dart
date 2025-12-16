/// Models defining the state and progress of the synchronization process.
library;

import 'package:pharma_scan/core/services/data_initialization_service.dart';

enum SyncPhase {
  idle,
  waitingNetwork,
  waitingUser,
  checking,
  downloading,
  applying,
  success,
  error,
}

enum SyncStatusCode {
  idle,
  waitingNetwork,
  checkingUpdates,
  downloadingSource,
  applyingUpdate,
  successAlreadyCurrent,
  successUpdatesApplied,
  successVerified,
  error,
}

enum SyncErrorType { network, scraping, download, apply, unknown }

class SyncProgress {
  const SyncProgress({
    required this.phase,
    required this.code,
    this.progress,
    this.subject,
    this.errorType,
    this.startTime,
    this.totalBytes,
    this.receivedBytes,
    this.pendingUpdate,
  });

  final SyncPhase phase;
  final SyncStatusCode code;
  final double? progress;
  final String? subject;
  final SyncErrorType? errorType;
  final DateTime? startTime;
  final int? totalBytes;
  final int? receivedBytes;
  final VersionCheckResult? pendingUpdate;

  static const idle = SyncProgress(
    phase: SyncPhase.idle,
    code: SyncStatusCode.idle,
  );

  Duration? get elapsed =>
      startTime != null ? DateTime.now().difference(startTime!) : null;

  Duration? get estimatedRemaining {
    final elapsedDuration = elapsed;
    if (elapsedDuration == null || progress == null || progress! <= 0) {
      return null;
    }
    final totalMicros = elapsedDuration.inMicroseconds / progress!;
    final remainingMicros = totalMicros - elapsedDuration.inMicroseconds;
    if (remainingMicros <= 0) return Duration.zero;
    return Duration(microseconds: remainingMicros.round());
  }
}
