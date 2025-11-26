// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/core/providers/theme_provider.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/theme/app_colors.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // WHY: Initialize logger in background to avoid blocking app startup
  Future.microtask(() {
    LoggerService().init();
    LoggerService.info('🚀 App Starting...');
  });

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
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

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

class PharmaScanApp extends ConsumerStatefulWidget {
  const PharmaScanApp({super.key});

  @override
  ConsumerState<PharmaScanApp> createState() => PharmaScanAppState();
}

class PharmaScanAppState extends ConsumerState<PharmaScanApp> {
  late final ShadTextTheme _headingTextTheme = _buildHeadingTextTheme();

  @override
  void initState() {
    super.initState();
    // WHY: Start initialization immediately without waiting for first frame
    // The initialization provider already starts with success state, so this is safe
    Future.microtask(_initializeDatabase);
  }

  Future<void> _initializeDatabase() async {
    // WHY: Don't await - let initialization happen in background
    // The provider already starts with success state, so app remains responsive
    ref.read(initializationStateProvider.notifier).initialize();
  }

  ShadTextTheme _buildHeadingTextTheme() {
    final base = ShadTextTheme();
    return base.copyWith(
      h3: base.h3.copyWith(fontWeight: FontWeight.w700),
      h4: base.h4.copyWith(fontWeight: FontWeight.w600),
    );
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(goRouterProvider);
    final themeAsync = ref.watch(themeProvider);
    final themeMode = themeAsync.value ?? ThemeMode.system;

    // WHY: Always show the router - initialization happens in background
    // with reactive feedback via toasts and placeholders
    return ShadApp.router(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadZincColorScheme.light(
          background: AppColors.scaffoldOffWhite,
          custom: AppColors.semanticCustomColors,
        ),
        textTheme: _headingTextTheme,
        // WHY: Configure default button theme for consistency
        // Note: Gradient and shadow must still be applied per-button
        primaryButtonTheme: const ShadButtonTheme(),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadSlateColorScheme.dark(
          background: AppColors.scaffoldSlateDark,
          custom: AppColors.semanticCustomColors,
        ),
        textTheme: _headingTextTheme,
        // WHY: Configure default button theme for consistency
        // Note: Gradient and shadow must still be applied per-button
        primaryButtonTheme: const ShadButtonTheme(),
      ),
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
        return ShadSonner(alignment: Alignment.topCenter, child: child!);
      },
      routerConfig: goRouter,
    );
  }
}
