import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'navigation_provider.g.dart';

@riverpod
class CanSwipeRoot extends _$CanSwipeRoot {
  @override
  bool build() => true;

  bool get canSwipe => state;

  set canSwipe(bool value) {
    state = value;
  }
}
