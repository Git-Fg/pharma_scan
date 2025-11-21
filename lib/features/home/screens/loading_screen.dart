// lib/features/home/screens/loading_screen.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/utils/strings.dart';
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
                const Gap(24),
                Text(Strings.appName, style: theme.textTheme.h2),
                const Gap(8),
                Text(
                  Strings.databaseInitialization,
                  style: theme.textTheme.muted,
                  textAlign: TextAlign.center,
                ),
                const Gap(32),
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
