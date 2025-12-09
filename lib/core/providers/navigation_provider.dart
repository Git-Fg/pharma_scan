import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'navigation_provider.g.dart';

typedef TabReselectionSignal = ({int tabIndex, int tick});

@riverpod
class CanSwipeRoot extends _$CanSwipeRoot {
  @override
  bool build() => true;

  bool get canSwipe => state;

  set canSwipe(bool value) {
    state = value;
  }
}

@riverpod
class TabReselection extends _$TabReselection {
  @override
  TabReselectionSignal build() => (tabIndex: -1, tick: 0);

  void ping(int tabIndex) {
    state = (tabIndex: tabIndex, tick: state.tick + 1);
  }
}
