// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/providers/theme_provider.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:forui/forui.dart';
import 'package:pharma_scan/theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // WHY: Initialize logger in background to avoid blocking app startup
  unawaited(
    Future.microtask(() {
      LoggerService().init();
      LoggerService.info('🚀 App Starting...');
    }),
  );

  // Configure global animation defaults for consistency
  Animate.defaultDuration = 300.ms;
  Animate.defaultCurve = Curves.easeOutCubic;

  // Configure SystemUI for Android (status bar and navigation bar)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

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
            enabled: true,
            printStateFullData: false,
            printProviderAdded: false,
            printProviderDisposed: true,
            printProviderFailed: true,
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
    final goRouter = ref.watch(goRouterProvider);
    final themeAsync = ref.watch(themeProvider);
    final themeMode = themeAsync.value ?? ThemeMode.system;

    // WHY: Use Forui Green themes with Material compatibility
    final foruiLightTheme = greenLight;
    final foruiDarkTheme = greenDark;

    // WHY: Convert Forui themes to Material themes for system UI and Material widgets
    final lightTheme = foruiLightTheme.toApproximateMaterialTheme();
    final darkTheme = foruiDarkTheme.toApproximateMaterialTheme();

    // WHY: Always show the router - initialization happens in background
    // with reactive feedback via toasts and placeholders
    // WHY: Wrap with FAnimatedTheme to provide Forui theme globally
    return MaterialApp.router(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: lightTheme,
      darkTheme: darkTheme,
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: const [...FLocalizations.localizationsDelegates],
      builder: (context, child) {
        // WHY: Update SystemUI overlay style based on theme brightness
        // This ensures status bar and navigation bar icons match the current theme
        final brightness = Theme.of(context).brightness;
        SystemChrome.setSystemUIOverlayStyle(
          SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: brightness == Brightness.dark
                ? Brightness.dark
                : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
        );
        // WHY: Wrap with FAnimatedTheme to provide Forui theme context
        final activeForuiTheme = brightness == Brightness.dark
            ? foruiDarkTheme
            : foruiLightTheme;
        return FAnimatedTheme(data: activeForuiTheme, child: child!);
      },
      routerConfig: goRouter,
    );
  }
}
