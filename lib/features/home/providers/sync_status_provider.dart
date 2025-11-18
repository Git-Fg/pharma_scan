import 'package:riverpod/riverpod.dart';
import 'package:pharma_scan/core/services/sync_service.dart';

class SyncStatusNotifier extends Notifier<SyncProgress> {
  @override
  SyncProgress build() => const SyncProgress(phase: SyncPhase.idle);

  void updateStatus(SyncProgress progress) {
    state = progress;
  }
}

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncProgress>(
  SyncStatusNotifier.new,
);
