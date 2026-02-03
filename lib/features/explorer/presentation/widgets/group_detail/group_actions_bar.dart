import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/services/logger_service.dart';

import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class GroupActionsBar extends StatelessWidget {
  const GroupActionsBar({
    required this.cisCode,
    required this.ansmAlertUrl,
    super.key,
  });

  final String? cisCode;
  final String? ansmAlertUrl;

  @override
  Widget build(BuildContext context) {
    if (cisCode == null || cisCode!.isEmpty) {
      return const SizedBox.shrink();
    }

    /// Generate ANSM fiche URL for a given CIS code
    String ficheAnsm(String cisCode) =>
        'https://base-donnees-publique.medicaments.gouv.fr/extrait.php?specid=$cisCode';

    /// Generate ANSM RCP (Résumé des Caractéristiques du Produit) URL for a given CIS code
    String rcpAnsm(String cisCode) =>
        'https://base-donnees-publique.medicaments.gouv.fr/medicament/$cisCode/extrait#tab-rcp';

    final ficheUrl = ficheAnsm(cisCode!);
    final rcpUrl = rcpAnsm(cisCode!);

    return Padding(
      padding: const .only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ansmAlertUrl != null && ansmAlertUrl!.isNotEmpty) ...[
            ShadButton.destructive(
              onPressed: () => _launchUrl(context, ansmAlertUrl!),
              child: const Icon(LucideIcons.triangleAlert),
            ),
            const Gap(12),
          ],
          ShadResponsiveBuilder(
            builder: (context, breakpoint) {
              // horizontalPadding not used locally anymore

              // Using static check for narrow screen
              final isNarrow = MediaQuery.sizeOf(context).width < 640;
              final ficheButton = ShadButton.secondary(
                onPressed: () => _launchUrl(context, ficheUrl),
                child: const Icon(LucideIcons.info),
              );

              final rcpButton = ShadButton.outline(
                onPressed: () => _launchUrl(context, rcpUrl),
                child: const Icon(LucideIcons.fileText),
              );

              if (!isNarrow) {
                return Row(
                  children: [
                    Expanded(child: ficheButton),
                    const Gap(12),
                    Expanded(child: rcpButton),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [ficheButton, const Gap(12), rcpButton],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri);
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: context.colors.destructive,
            content: Text('${Strings.unableToOpenUrl}: $url'),
          ),
        );
      }
      LoggerService().error('Failed to launch URL: $url', e);
    }
  }
}
