import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/models/update_frequency.dart';
import 'package:pharma_scan/core/providers/preferences_provider.dart';
import 'package:pharma_scan/features/home/providers/sync_status_provider.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/services/sync_service.dart';
import 'package:pharma_scan/core/utils/theme_preferences.dart';
import 'package:pharma_scan/main.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  ThemeSetting _currentTheme = ThemeSetting.system;
  bool _isResetting = false;
  bool _isCheckingUpdates = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentTheme = PharmaScanApp.of(context).themeSetting;
  }

  void _onThemeChanged(ThemeSetting value) {
    PharmaScanApp.of(context).setTheme(value);
    setState(() {
      _currentTheme = value;
    });
  }

  void _showResetConfirmation() {
    showShadDialog(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('Réinitialiser la base de données ?'),
        description: const Text(
          'Cette action supprimera toutes les données locales et les re-téléchargera. '
          'Cette opération est irréversible et peut prendre plusieurs minutes.',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ShadButton.destructive(
            onPressed: _performReset,
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  Future<void> _performReset() async {
    Navigator.of(context).pop();
    setState(() {
      _isResetting = true;
    });

    try {
      await sl<DataInitializationService>().initializeDatabase(
        forceRefresh: true,
      );

      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            title: const Text('Réinitialisation terminée'),
            description: const Text(
              'La base de données a été mise à jour avec succès.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text('Erreur de réinitialisation'),
            description: const Text(
              'Impossible de re-télécharger les données. Vérifiez votre connexion internet.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }

  Future<void> _runManualSync() async {
    if (_isCheckingUpdates) return;
    setState(() {
      _isCheckingUpdates = true;
    });

    showShadDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SyncProgressDialog(),
    );

    try {
      final updated = await sl<SyncService>().checkForUpdates(
        resolveFrequency: () => ref.read(appPreferencesProvider.future),
        reportStatus: (progress) =>
            ref.read(syncStatusProvider.notifier).updateStatus(progress),
        force: true,
      );
      if (!mounted) return;
      ShadToaster.of(context).show(
        ShadToast(
          title: Text(
            updated ? 'Base BDPM synchronisée' : 'Aucune nouvelle mise à jour',
          ),
          description: Text(
            updated
                ? 'Les dernières données BDPM ont été appliquées.'
                : 'Vos données locales sont déjà à jour.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ShadToaster.of(context).show(
        const ShadToast.destructive(
          title: Text('Synchronisation échouée'),
          description: Text(
            'Impossible de vérifier les dernières données BDPM. Réessayez plus tard.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _isCheckingUpdates = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final frequencyState = ref.watch(appPreferencesProvider);
    final updateFrequency = frequencyState.value ?? UpdateFrequency.daily;
    final isFrequencyLoading = frequencyState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Réglages'),
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.foreground),
      ),
      backgroundColor: theme.colorScheme.background,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Apparence', style: theme.textTheme.h4),
                const SizedBox(height: 16),
                ShadRadioGroup<ThemeSetting>(
                  initialValue: _currentTheme,
                  onChanged: (value) {
                    if (value != null) _onThemeChanged(value);
                  },
                  items: const [
                    ShadRadio<ThemeSetting>(
                      value: ThemeSetting.system,
                      label: Text('Thème du système'),
                    ),
                    ShadRadio<ThemeSetting>(
                      value: ThemeSetting.light,
                      label: Text('Thème clair'),
                    ),
                    ShadRadio<ThemeSetting>(
                      value: ThemeSetting.dark,
                      label: Text('Thème sombre'),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Text('Synchronisation', style: theme.textTheme.h4),
                const SizedBox(height: 16),
                ShadRadioGroup<UpdateFrequency>(
                  initialValue: updateFrequency,
                  onChanged: isFrequencyLoading
                      ? null
                      : (value) async {
                          if (value == null) return;
                          await ref
                              .read(appPreferencesProvider.notifier)
                              .setUpdateFrequency(value);
                        },
                  items: const [
                    ShadRadio<UpdateFrequency>(
                      value: UpdateFrequency.none,
                      label: Text('Ne jamais rechercher'),
                    ),
                    ShadRadio<UpdateFrequency>(
                      value: UpdateFrequency.daily,
                      label: Text('Une fois par jour'),
                    ),
                    ShadRadio<UpdateFrequency>(
                      value: UpdateFrequency.weekly,
                      label: Text('Une fois par semaine'),
                    ),
                    ShadRadio<UpdateFrequency>(
                      value: UpdateFrequency.monthly,
                      label: Text('Une fois par mois'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Détermine la fréquence de vérification des nouvelles données BDPM.',
                  style: theme.textTheme.muted,
                ),
                const SizedBox(height: 48),
                Text('Données', style: theme.textTheme.h4),
                const SizedBox(height: 16),
                ShadButton(
                  onPressed: _isCheckingUpdates ? null : _runManualSync,
                  leading: const Icon(LucideIcons.refreshCw, size: 16),
                  child: Text(
                    _isCheckingUpdates
                        ? 'Vérification en cours...'
                        : 'Vérifier les mises à jour maintenant',
                  ),
                ),
                const SizedBox(height: 12),
                ShadButton.destructive(
                  onPressed: _showResetConfirmation,
                  leading: const Icon(LucideIcons.databaseZap, size: 16),
                  child: const Text('Forcer la réinitialisation de la base'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Utilisez cette option si les données semblent corrompues ou pour forcer une mise à jour manuelle.',
                  style: theme.textTheme.muted,
                ),
              ],
            ),
          ),
          if (_isResetting)
            Container(
              color: theme.colorScheme.background.withValues(alpha: 0.8),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShadProgress(),
                    SizedBox(height: 16),
                    Text('Réinitialisation en cours...'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SyncProgressDialog extends StatelessWidget {
  const _SyncProgressDialog();

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadDialog(
      title: const Text('Vérification des mises à jour'),
      description: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          const ShadProgress(),
          const SizedBox(height: 12),
          Text(
            'Patientez pendant la synchronisation avec le BDPM…',
            style: theme.textTheme.muted,
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: const [],
    );
  }
}
