// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pharma_scan/features/scanner/screens/camera_screen.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';

void main() async {
  // Cette partie sera complétée pour l'initialisation de la base de données
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lancer l'initialisation de la base de données
  await DataInitializationService().initializeDatabase();
  
  runApp(const PharmaScanApp());
}

class PharmaScanApp extends StatelessWidget {
  const PharmaScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'PharmaScan',
      debugShowCheckedModeBanner: false,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadZincColorScheme.light(),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadSlateColorScheme.dark(),
      ),
      builder: (context, child) {
        return ShadToaster(
          child: child!,
        );
      },
      home: const CameraScreen(), // Notre écran principal
    );
  }
}
