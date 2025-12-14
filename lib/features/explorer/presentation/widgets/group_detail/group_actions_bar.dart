import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/ui/molecules/app_button.dart';
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
      padding: const EdgeInsets.only(top: AppDimens.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ansmAlertUrl != null && ansmAlertUrl!.isNotEmpty) ...[
            AppButton.icon(
              onPressed: () => _launchUrl(context, ansmAlertUrl!),
              variant: ButtonVariant.destructive,
              size: ButtonSize.medium,
              icon: LucideIcons.triangleAlert,
              label: Strings.shortageAlert,
            ),
            const Gap(AppDimens.spacingSm),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              final ficheButton = AppButton.icon(
                onPressed: () => _launchUrl(context, ficheUrl),
                variant: ButtonVariant.secondary,
                size: ButtonSize.medium,
                icon: LucideIcons.info,
                label: Strings.ficheInfo,
              );

              final rcpButton = AppButton.icon(
                onPressed: () => _launchUrl(context, rcpUrl),
                variant: ButtonVariant.outline,
                size: ButtonSize.medium,
                icon: LucideIcons.fileText,
                label: Strings.rcpDocument,
              );

              if (!isNarrow) {
                return Row(
                  children: [
                    Expanded(child: ficheButton),
                    const Gap(AppDimens.spacingSm),
                    Expanded(child: rcpButton),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ficheButton,
                  const Gap(AppDimens.spacingSm),
                  rcpButton,
                ],
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
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('${Strings.unableToOpenUrl}: $url'),
          ),
        );
      }
      LoggerService.error('Failed to launch URL: $url', e);
    }
  }
}
