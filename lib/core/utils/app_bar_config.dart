import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Immutable configuration for the app's top bar.
class AppBarConfig {
  final Widget title;
  final List<Widget> actions;
  final bool showBackButton;
  final bool isVisible;

  const AppBarConfig({
    required this.title,
    this.actions = const [],
    this.showBackButton = false,
    this.isVisible = true,
  });

  static const AppBarConfig hidden = AppBarConfig(
    title: SizedBox.shrink(),
    actions: [],
    showBackButton: false,
    isVisible: false,
  );

  AppBarConfig copyWith({
    Widget? title,
    List<Widget>? actions,
    bool? showBackButton,
    bool? isVisible,
  }) {
    return AppBarConfig(
      title: title ?? this.title,
      actions: actions ?? this.actions,
      showBackButton: showBackButton ?? this.showBackButton,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppBarConfig &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          listEquals(actions, other.actions) &&
          showBackButton == other.showBackButton &&
          isVisible == other.isVisible;

  @override
  int get hashCode =>
      Object.hash(title, Object.hashAll(actions), showBackButton, isVisible);
}
