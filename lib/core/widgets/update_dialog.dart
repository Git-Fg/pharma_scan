import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/core/database/providers.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class UpdateDialog extends ConsumerWidget {
  const UpdateDialog({
    super.key,
    required this.versionResult,
  });

  final VersionCheckResult versionResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);

    return ShadDialog(
      title: const Text('Mise à jour disponible'),
      description: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Une nouvelle version de la base de données est disponible.',
              style: theme.textTheme.p,
            ),
            const SizedBox(height: 8),
            _buildVersionRow(
                'Version actuelle :', versionResult.localDate ?? 'Inconnue'),
            _buildVersionRow('Nouvelle version :', versionResult.remoteTag),
            const SizedBox(height: 12),
            Text(
              'Voulez-vous la télécharger maintenant ?',
              style: theme.textTheme.p,
            ),
          ],
        ),
      ),
      actions: [
        ShadButton.outline(
          onPressed: () {
            // "Plus tard" -> Just close
            Navigator.of(context).pop(false);
          },
          child: const Text('Plus tard'),
        ),
        ShadButton.outline(
          onPressed: () async {
            // "Ne plus demander" -> Set policy to 'never'
            final db = ref.read(databaseProvider());
            await db.appSettingsDao.setUpdatePolicy('never');
            if (context.mounted) {
              Navigator.of(context).pop(false);
              ShadToaster.of(context).show(
                const ShadToast(
                  title: Text('Mises à jour désactivées'),
                  description:
                      Text('Vous pouvez modifier ce choix dans les réglages.'),
                ),
              );
            }
          },
          child: const Text('Ne plus demander'),
        ),
        ShadButton(
          onPressed: () {
            Navigator.of(context).pop(true);
          },
          child: const Text('Mettre à jour'),
        ),
      ],
    );
  }

  Widget _buildVersionRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ],
    );
  }
}
