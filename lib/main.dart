// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/utils/theme_preferences.dart';
import 'package:pharma_scan/features/home/screens/loading_screen.dart';
import 'package:pharma_scan/features/home/screens/main_screen.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the service locator
  await setupLocator();

  runApp(const ProviderScope(child: PharmaScanApp()));
}

class PharmaScanApp extends StatefulWidget {
  const PharmaScanApp({super.key});

  @override
  State<PharmaScanApp> createState() => PharmaScanAppState();

  static PharmaScanAppState of(BuildContext context) =>
      context.findAncestorStateOfType<PharmaScanAppState>()!;
}

class PharmaScanAppState extends State<PharmaScanApp> {
  InitializationState _initState = InitializationState.initializing;
  ThemeSetting _themeSetting = ThemeSetting.system;

  ThemeSetting get themeSetting => _themeSetting;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initializeDatabase();
  }

  Future<void> _loadTheme() async {
    final theme = await ThemePreferences.getTheme();
    setTheme(theme);
  }

  void setTheme(ThemeSetting setting) {
    setState(() {
      _themeSetting = setting;
    });
    ThemePreferences.setTheme(setting);
  }

  Future<void> _initializeDatabase() async {
    try {
      setState(() {
        _initState = InitializationState.initializing;
      });
      await sl<DataInitializationService>().initializeDatabase();

      if (mounted) {
        setState(() {
          _initState = InitializationState.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initState = InitializationState.error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'PharmaScan',
      debugShowCheckedModeBanner: false,
      themeMode: ThemePreferences.toThemeMode(_themeSetting),
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadZincColorScheme.light(),
        primaryToastTheme: const ShadToastTheme(alignment: Alignment.topCenter),
        destructiveToastTheme: const ShadToastTheme(
          alignment: Alignment.topCenter,
        ),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadSlateColorScheme.dark(),
        primaryToastTheme: const ShadToastTheme(alignment: Alignment.topCenter),
        destructiveToastTheme: const ShadToastTheme(
          alignment: Alignment.topCenter,
        ),
      ),
      builder: (context, child) {
        return ShadToaster(child: child!);
      },
      home: _initState == InitializationState.initializing
          ? const LoadingScreen()
          : MainScreen(
              initState: _initState,
              onRetryInitialization: _initializeDatabase,
            ),
    );
  }
}
