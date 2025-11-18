import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'preferences_provider.g.dart';

const _frequencyKey = 'sync_update_frequency';

@riverpod
class AppPreferences extends _$AppPreferences {
  SharedPreferences get _prefs => sl<SharedPreferences>();

  @override
  Future<UpdateFrequency> build() async {
    final stored = _prefs.getString(_frequencyKey);
    return UpdateFrequency.fromStorage(stored);
  }

  Future<void> setUpdateFrequency(UpdateFrequency newFrequency) async {
    await _prefs.setString(_frequencyKey, newFrequency.storageValue);
    state = AsyncData(newFrequency);
  }
}
