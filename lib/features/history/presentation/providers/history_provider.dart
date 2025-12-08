import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/features/history/domain/entities/scan_history_entry.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'history_provider.g.dart';

@riverpod
class HistoryController extends _$HistoryController {
  @override
  Stream<List<ScanHistoryEntry>> build() {
    final limitAsync = ref.watch(scanHistoryLimitProvider);
    final limit = limitAsync.value ?? 100;
    final dao = ref.watch(appDatabaseProvider).restockDao;
    return dao.watchScanHistory(limit);
  }

  Future<void> clearHistory() async {
    // Mark loading so UI can disable the clear button while the stream refreshes.
    state = const AsyncLoading();
    await ref.read(appDatabaseProvider).restockDao.clearHistory();
  }
}
