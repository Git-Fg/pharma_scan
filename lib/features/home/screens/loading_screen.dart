// lib/features/home/screens/loading_screen.dart
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.database,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text('PharmaScan', style: theme.textTheme.h2),
                const SizedBox(height: 8),
                Text(
                  'Initialisation de la base de données...',
                  style: theme.textTheme.muted,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: const ShadProgress(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
