import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'navigation_provider.g.dart';

/// Controls whether root-level tab swiping is enabled.
/// Set to false when in nested routes to prevent gesture conflicts.
@riverpod
class CanSwipeRoot extends _$CanSwipeRoot {
  @override
  bool build() => true; // Default: swiping enabled

  bool get canSwipe => state;

  set canSwipe(bool value) {
    state = value;
  }
}
