// lib/features/home/models/sync_state.dart
/// Models defining the state and progress of the synchronization process.
library;

enum SyncPhase {
  idle,
  waitingNetwork,
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
  });

  final SyncPhase phase;
  final SyncStatusCode code;
  final double? progress;
  final String? subject;
  final SyncErrorType? errorType;

  static const idle = SyncProgress(
    phase: SyncPhase.idle,
    code: SyncStatusCode.idle,
  );

  SyncProgress copyWith({
    SyncPhase? phase,
    SyncStatusCode? code,
    double? progress,
    String? subject,
    SyncErrorType? errorType,
  }) {
    return SyncProgress(
      phase: phase ?? this.phase,
      code: code ?? this.code,
      progress: progress ?? this.progress,
      subject: subject ?? this.subject,
      errorType: errorType ?? this.errorType,
    );
  }
}
