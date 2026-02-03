import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:auto_route/auto_route.dart';
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

  // Try to find the parent tab router - gracefully handle screens outside tabs
  TabsRouter? tabsRouter;
  try {
    tabsRouter = AutoTabsRouter.of(context);
  } catch (_) {
    // Not inside an AutoTabsRouter - this is fine for screens like Settings
    tabsRouter = null;
  }

  // Only set config if we're inside a tab router context
  if (tabsRouter == null) return;

  final tabIndex = tabsRouter.activeIndex;

  final config = AppBarConfig(
    title: title,
    actions: actions,
    showBackButton: showBackButton,
    isVisible: isVisible,
  );

  useEffect(() {
    // Register the config for this specific tab index
    Future.microtask(() {
      if (context.mounted) {
        container
            .read(appBarStateProvider.notifier)
            .setConfigForIndex(tabIndex, config);
      }
    });

    return null; // Don't unregister, the next screen in the tab will overwrite it
  }, [tabIndex, config]); // config equality is handled by AppBarConfig.==
}
