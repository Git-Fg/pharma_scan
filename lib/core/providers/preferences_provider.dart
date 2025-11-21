import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/providers/core_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'preferences_provider.g.dart';

@riverpod
class AppPreferences extends _$AppPreferences {
  @override
  Stream<UpdateFrequency> build() {
    final db = ref.watch(driftDatabaseServiceProvider);
    return db.watchSettings().map(
      (settings) => UpdateFrequency.fromStorage(settings.updateFrequency),
    );
  }

  Future<void> setUpdateFrequency(UpdateFrequency newFrequency) async {
    await ref
        .read(driftDatabaseServiceProvider)
        .updateSyncFrequency(newFrequency.storageValue);
  }
}
