import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/providers/theme_provider.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/router/router_provider.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/utils/navigation_helpers.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  unawaited(
    Future.microtask(() {
      LoggerService().init();
      LoggerService.info('🚀 App Starting...');
    }),
  );

  runApp(
    ProviderScope(
      retry: (retryCount, error) {
        if (retryCount >= 5) return null;
        return Duration(milliseconds: 200 * (1 << retryCount));
      },
      observers: [
        TalkerRiverpodObserver(
          talker: LoggerService().talker,
          settings: const TalkerRiverpodLoggerSettings(
            printStateFullData: false,
            printProviderAdded: false,
            printProviderDisposed: true,
          ),
        ),
      ],
      child: const PharmaScanApp(),
    ),
  );
}

class PharmaScanApp extends HookConsumerWidget {
  const PharmaScanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      unawaited(
        Future.microtask(() async {
          await ref.read(initializationStateProvider.notifier).initialize();
        }),
      );
      return null;
    }, []);
    final appRouter = ref.watch(appRouterProvider);
    final themeAsync = ref.watch(themeProvider);
    final themeMode = themeAsync.value ?? ThemeMode.system;

    useEffect(() {
      const quickActions = QuickActions();
      unawaited(
        quickActions.initialize((type) {
          switch (type) {
            case 'action_scan':
              unawaited(() async {
                final navContext =
                    appRouter.navigatorKey.currentContext ?? context;
                await ref.navigateToRestockMode(navContext);
                await appRouter.navigate(const ScannerTabRoute());
              }());
            case 'action_search':
              unawaited(appRouter.navigate(const ExplorerTabRoute()));
          }
        }),
      );
      unawaited(
        quickActions.setShortcutItems(const [
          ShortcutItem(
            type: 'action_scan',
            localizedTitle: Strings.shortcutScanToRestock,
            icon: 'scan',
          ),
          ShortcutItem(
            type: 'action_search',
            localizedTitle: Strings.shortcutSearchDatabase,
            icon: 'search',
          ),
        ]),
      );
      return null;
    }, [appRouter]);

    return ShadApp.custom(
      themeMode: themeMode,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadGreenColorScheme.light(
          primary: Color(0xFF0F766E),
        ),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadGreenColorScheme.dark(
          primary: Color(0xFF14B8A6),
        ),
      ),
      appBuilder: (context) {
        return MaterialApp.router(
          title: Strings.appName,
          theme: Theme.of(context),
          darkTheme: Theme.of(context),
          supportedLocales: const [Locale('fr', '')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => ShadAppBuilder(child: child),
          routerConfig: appRouter.config(),
        );
      },
    );
  }
}
