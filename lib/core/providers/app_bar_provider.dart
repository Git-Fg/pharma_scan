import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../utils/app_bar_config.dart';

part 'app_bar_provider.g.dart';

@Riverpod(keepAlive: true)
class AppBarState extends _$AppBarState {
  @override
  AppBarConfig build() => const AppBarConfig(
        title: SizedBox.shrink(),
        actions: [],
        showBackButton: false,
        isVisible: true,
      );

  void setConfig(AppBarConfig config) => state = config;

  void reset() => state = const AppBarConfig(
        title: SizedBox.shrink(),
        actions: [],
        showBackButton: false,
        isVisible: true,
      );
}
