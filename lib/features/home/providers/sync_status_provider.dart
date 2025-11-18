import 'package:pharma_scan/core/services/sync_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sync_status_provider.g.dart';

@riverpod
class SyncStatusNotifier extends _$SyncStatusNotifier {
  @override
  SyncProgress build() => const SyncProgress(phase: SyncPhase.idle);

  void updateStatus(SyncProgress progress) {
    state = progress;
  }
}
