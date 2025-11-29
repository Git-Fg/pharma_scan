// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/providers/theme_provider.dart';
import 'package:pharma_scan/core/router/router_provider.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // WHY: Initialize logger in background to avoid blocking app startup
  unawaited(
    Future.microtask(() {
      LoggerService().init();
      LoggerService.info('🚀 App Starting...');
    }),
  );

  // Configure global animation defaults for consistency (if needed in future)
  // Animate.defaultDuration = 300.ms;
  // Animate.defaultCurve = Curves.easeOutCubic;

  // Enable edge-to-edge display on Android
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));

  runApp(
    ProviderScope(
      // WHY: Configure automatic retries for network operations with exponential backoff.
      // Riverpod 3.0's built-in retry mechanism handles transient network failures
      // automatically, reducing the need for custom retry logic in providers.
      retry: (retryCount, error) {
        // Limit retries to prevent infinite loops
        if (retryCount >= 5) return null;

        // Exponential backoff: 200ms, 400ms, 800ms, 1600ms, 3200ms
        // This reduces server load and handles transient network issues gracefully
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
    // WHY: Start initialization immediately without waiting for first frame
    // The initialization provider already starts with success state, so this is safe
    useEffect(() {
      unawaited(
        Future.microtask(() {
          // WHY: Don't await - let initialization happen in background
          // The provider already starts with success state, so app remains responsive
          ref.read(initializationStateProvider.notifier).initialize();
        }),
      );
      return null;
    }, []);
    final appRouter = ref.watch(appRouterProvider);
    final themeAsync = ref.watch(themeProvider);
    final themeMode = themeAsync.value ?? ThemeMode.system;

    // WHY: Use Shadcn Green color scheme for consistent theming
    // ShadApp.custom with MaterialApp.router provides Material integration for Scaffold/AppBar/NavigationBar
    // while maintaining Shadcn theme context and AutoRoute integration
    return ShadApp.custom(
      themeMode: themeMode,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadGreenColorScheme.light(),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadGreenColorScheme.dark(),
      ),
      appBuilder: (BuildContext shadContext) {
        return MaterialApp.router(
          title: Strings.appName,
          debugShowCheckedModeBanner: false,
          theme: Theme.of(shadContext),
          darkTheme: Theme.of(shadContext),
          routerConfig: appRouter.config(),
          supportedLocales: const [Locale('fr', '')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (BuildContext materialContext, Widget? child) {
            return ShadAppBuilder(child: child);
          },
        );
      },
    );
  }
}
