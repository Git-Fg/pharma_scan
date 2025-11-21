// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/core/providers/theme_provider.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:pharma_scan/features/home/screens/loading_screen.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:talker_riverpod_logger/talker_riverpod_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  LoggerService().init();
  LoggerService.info('🚀 App Starting...');

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
  @override
  void initState() {
    super.initState();
    // WHY: Defer provider mutations until after the first frame to avoid
    // touching Riverpod state during the initial build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDatabase();
    });
  }

  Future<void> _initializeDatabase() async {
    await ref.read(initializationStateProvider.notifier).initialize();
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(goRouterProvider);
    final initState = ref.watch(initializationStateProvider);
    final themeAsync = ref.watch(themeProvider);
    final themeMode = themeAsync.value ?? ThemeMode.system;

    // Show loading screen during initialization
    if (initState == InitializationState.initializing) {
      return ShadApp(
        title: 'PharmaScan',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: ShadThemeData(
          brightness: Brightness.light,
          colorScheme: const ShadZincColorScheme.light(),
        ),
        darkTheme: ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: const ShadSlateColorScheme.dark(),
        ),
        builder: (context, child) {
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
          return ShadSonner(child: child!);
        },
        home: const LoadingScreen(),
      );
    }

    return ShadApp.router(
      title: 'PharmaScan',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadZincColorScheme.light(),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadSlateColorScheme.dark(),
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
        return ShadSonner(child: child!);
      },
      routerConfig: goRouter,
    );
  }
}
