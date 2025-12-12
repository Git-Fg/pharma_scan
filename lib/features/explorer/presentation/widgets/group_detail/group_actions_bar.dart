import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class GroupActionsBar extends StatelessWidget {
  const GroupActionsBar({
    required this.cisCode, required this.ansmAlertUrl, super.key,
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
            ShadButton.destructive(
              width: double.infinity,
              onPressed: () => _launchUrl(context, ansmAlertUrl!),
              leading: const Icon(
                LucideIcons.triangleAlert,
                size: AppDimens.iconSm,
              ),
              child: const Text(Strings.shortageAlert),
            ),
            const Gap(AppDimens.spacingSm),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              final ficheButton = ShadButton.secondary(
                width: double.infinity,
                onPressed: () => _launchUrl(context, ficheUrl),
                leading: Icon(
                  LucideIcons.info,
                  size: AppDimens.iconSm,
                  color: context.shadColors.secondaryForeground,
                ),
                child: const Text(Strings.ficheInfo),
              );

              final rcpButton = ShadButton.outline(
                width: double.infinity,
                onPressed: () => _launchUrl(context, rcpUrl),
                leading: Icon(
                  LucideIcons.fileText,
                  size: AppDimens.iconSm,
                  color: context.shadColors.foreground,
                ),
                child: const Text(Strings.rcpDocument),
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
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text(Strings.error),
            description: Text('${Strings.unableToOpenUrl}: $url'),
          ),
        );
      }
      LoggerService.error('Failed to launch URL: $url', e);
    }
  }
}
