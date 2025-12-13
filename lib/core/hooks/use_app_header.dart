import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../providers/app_bar_provider.dart';
import '../utils/app_bar_config.dart';

/// Sets the app header config from a child screen.
///
/// Call at the top of your build method. Re-applies config on tab switch.
void useAppHeader({
  required Widget title,
  List<Widget> actions = const [],
  bool showBackButton = false,
  bool isVisible = true,
}) {
  final context = useContext();
  final container = ProviderScope.containerOf(context);

  final config = AppBarConfig(
    title: title,
    actions: actions,
    showBackButton: showBackButton,
    isVisible: isVisible,
  );

  // Re-apply config on build and when dependencies change.
  useEffect(() {
    // Defer provider modification to avoid modifying during widget tree build
    Future(() {
      container.read(appBarStateProvider.notifier).setConfig(config);
    });
    return null;
  }, [title, actions, showBackButton, isVisible]);
}
