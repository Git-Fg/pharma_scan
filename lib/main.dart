// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pharma_scan/features/home/screens/main_screen.dart';
import 'package:pharma_scan/features/home/screens/loading_screen.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the service locator
  setupLocator();

  runApp(const PharmaScanApp());
}

class PharmaScanApp extends StatefulWidget {
  const PharmaScanApp({super.key});

  @override
  State<PharmaScanApp> createState() => _PharmaScanAppState();
}

class _PharmaScanAppState extends State<PharmaScanApp> {
  bool _isInitializing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      setState(() {
        _errorMessage = null;
        _isInitializing = true;
      });
      await sl<DataInitializationService>().initializeDatabase();
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _showErrorDialog(BuildContext context) {
    showShadDialog(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('Erreur d\'initialisation'),
        description: Text(
          'Impossible d\'initialiser la base de données.\n\n'
          'Vérifiez votre connexion internet et réessayez.',
        ),
        actions: [
          ShadButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeDatabase();
            },
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show error dialog if initialization failed
    if (_errorMessage != null && !_isInitializing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted && _errorMessage != null) {
          _showErrorDialog(context);
          // Clear error message after showing dialog
          setState(() {
            _errorMessage = null;
          });
        }
      });
    }

    return ShadApp(
      title: 'PharmaScan',
      debugShowCheckedModeBanner: false,
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
      home: _isInitializing
          ? const LoadingScreen()
          : const MainScreen(), // Navigation principale avec Scanner et Explorer
    );
  }
}
