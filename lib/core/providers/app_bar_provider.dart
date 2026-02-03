import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../utils/app_bar_config.dart';

part 'app_bar_provider.g.dart';

@Riverpod(keepAlive: true)
class AppBarState extends _$AppBarState {
  @override
  Map<int, AppBarConfig> build() => {};

  void setConfigForIndex(int index, AppBarConfig config) {
    if (state[index] == config) return;
    state = {...state, index: config};
  }

  void reset() => state = {};
}
