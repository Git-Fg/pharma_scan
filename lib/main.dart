import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/mappers/mappable_library.dart';
import 'package:pharma_scan/core/providers/theme_provider.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/router/router_provider.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/file_download_service.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/services/preferences_service.dart';
import 'package:pharma_scan/core/utils/navigation_helpers.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // 1. Initialize bindings for plugins (PathProvider, SharedPreferences, etc.)
    WidgetsFlutterBinding.ensureInitialized();
    // 2. Initialize logging for this isolate
    LoggerService().init();

    try {
      if (taskName == 'weeklyDatabaseUpdate') {
        LoggerService.info('Starting background database update task...');

        // 3. Initialize dependencies manually (No Riverpod in background isolate)
        final prefs = await SharedPreferences.getInstance();
        final preferencesService = PreferencesService(prefs);

        // AppDatabase handles isolate sharing via native options automatically
        final database = AppDatabase();

        final fileDownloadService = FileDownloadService();

        final dataInitService = DataInitializationService(
          database: database,
          fileDownloadService: fileDownloadService,
          preferencesService: preferencesService,
        );

        // 4. Perform the update (force=false checks version tags first)
        final updated = await dataInitService.updateDatabase();

        LoggerService.info(
          'Background update completed. Updated: $updated',
        );

        // 5. Clean up resources
        await database.close();

        return Future.value(true);
      }
      return Future.value(false);
    } on Exception catch (e, stackTrace) {
      LoggerService.error('Workmanager task failed: $e', e, stackTrace);
      return Future.value(false);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeMappers();

  // Only initialize Workmanager on mobile platforms (not web)
  if (!kIsWeb) {
    unawaited(
      Workmanager().initialize(
        callbackDispatcher,
      ),
    );
  }

  unawaited(
    Future.microtask(() {
      LoggerService().init();
      LoggerService.info('🚀 App Starting...');
    }),
  );

  // Initialize SharedPreferences synchronously before app startup
  final prefs = await SharedPreferences.getInstance();
  final preferencesService = PreferencesService(prefs);

  runApp(
    ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(preferencesService),
      ],
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
            await ref.read(initializationStateProvider.notifier).initialize();
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
        // QuickActions only available on mobile platforms
        if (!kIsWeb) {
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
        }
        return null;
      },
      [appRouter],
    );

    return ShadApp.custom(
      themeMode: themeMode,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadGreenColorScheme.light(
          primary: Color(0xFF0F766E),
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
          primary: Color(0xFF14B8A6),
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
        );
      },
    );
  }
}
