import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/providers/theme_provider.dart';
import 'package:pharma_scan/app/router/app_router.dart';
import 'package:pharma_scan/app/router/router_provider.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/providers/initialization_provider.dart';
import 'package:pharma_scan/core/services/haptic_service.dart';
import 'package:pharma_scan/features/scanner/presentation/providers/scanner_provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  unawaited(
    Future.microtask(() {
      final logger = LoggerService()..init();
      logger.info('🚀 App Starting...');
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
    useEffect(
      () {
        unawaited(
          Future.microtask(() async {
            await ref.read(initializationProvider.notifier).retry();
          }),
        );
        return null;
      },
      [],
    );
    final appRouter = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeProvider);

    useEffect(
      () {
        const quickActions = QuickActions();
        unawaited(
          quickActions.initialize((type) {
            switch (type) {
              case 'action_scan':
                unawaited(() async {
                  final navContext =
                      appRouter.navigatorKey.currentContext ?? context;
                  // Inlined logic from navigation_helpers to avoid Core -> Feature violation
                  ref
                      .read(scannerProvider.notifier)
                      .setMode(ScannerMode.restock);
                  try {
                    AutoTabsRouter.of(navContext).setActiveIndex(0);
                  } on Object {
                    // Not inside a tab scaffold
                  }
                  await ref.read(hapticServiceProvider).restockSuccess();
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
      },
      [appRouter],
    );

    return ShadApp.custom(
      themeMode: themeMode,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadGreenColorScheme.light(
          // ignore: avoid_direct_colors
          primary: Color(0xFF0F766E),
        ),
        // Global radius configuration
        radius: BorderRadius.circular(12),
        // Component defaults using AppDimens values for consistency
        inputTheme: const ShadInputTheme(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        cardTheme: const ShadCardTheme(
          padding: EdgeInsets.all(16),
        ),
        // Set touch target sizes
        primaryButtonTheme: const ShadButtonTheme(
          height: 56,
          width: double.infinity, // Full width by default on mobile
        ),
        primaryToastTheme: const ShadToastTheme(
          alignment: Alignment.topCenter,
        ),
        destructiveToastTheme: const ShadToastTheme(
          alignment: Alignment.topCenter,
        ),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadGreenColorScheme.dark(
          // ignore: avoid_direct_colors
          primary: Color(0xFF14B8A6),
        ),
        // Global radius configuration
        radius: BorderRadius.circular(12),
        // Component defaults using AppDimens values for consistency
        inputTheme: const ShadInputTheme(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        cardTheme: const ShadCardTheme(
          padding: EdgeInsets.all(16), // spacingMd from AppDimens
        ),
        // Set touch target sizes
        primaryButtonTheme: const ShadButtonTheme(
          height: 56,
          width: double.infinity, // Full width by default on mobile
        ),
        primaryToastTheme: const ShadToastTheme(
          alignment: Alignment.topCenter,
        ),
        destructiveToastTheme: const ShadToastTheme(
          alignment: Alignment.topCenter,
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
          locale: const Locale('fr', ''),
          routerConfig: appRouter.config(),
          builder: (context, child) {
            return ShadToaster(child: child!);
          },
        );
      },
    );
  }
}
