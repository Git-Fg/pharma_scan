import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/constants/rcp_constants.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/domain/models/rcp_section_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class RcpShortcutsAccordion extends HookConsumerWidget {
  const RcpShortcutsAccordion({
    required this.cisCode,
    super.key,
  });

  final String cisCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);

    return ShadAccordion<String>.multiple(
      children: [
        ShadAccordionItem(
          value: 'rcp-shortcuts',
          title: Text(
            Strings.rcpQuickAccessTitle,
            style: theme.textTheme.p.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: RcpConstants.rcpHierarchy
                .map((RcpSection section) => _buildSection(context, section))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, RcpSection section) {
    final theme = ShadTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadButton.secondary(
          onPressed: () => _launchAnchor(
            context,
            section.anchor,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              section.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.small,
            ),
          ),
        ),
        if (section.subSections.isNotEmpty) ...[
          const Gap(AppDimens.spacingXs),
          Padding(
            padding: const EdgeInsets.only(
              left: AppDimens.spacingSm,
              bottom: AppDimens.spacingSm,
            ),
            child: Wrap(
              spacing: AppDimens.spacingXs,
              runSpacing: AppDimens.spacingXs,
              children: section.subSections.map((RcpSection subSection) {
                return ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: () => _launchAnchor(
                    context,
                    subSection.anchor,
                  ),
                  child: Text(
                    subSection.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.small,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _launchAnchor(
    BuildContext context,
    String anchor,
  ) async {
    final baseUrl =
        'https://base-donnees-publique.medicaments.gouv.fr/medicament/$cisCode/extrait';
    final fullUrl = '$baseUrl$anchor';

    try {
      final uri = Uri.parse(fullUrl);
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!success && context.mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text(Strings.error),
            description: Text('${Strings.unableToOpenUrl}: $fullUrl'),
          ),
        );
      }
    } on Exception catch (e, s) {
      if (context.mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text(Strings.error),
            description: Text('${Strings.unableToOpenUrl}: $fullUrl'),
          ),
        );
      }
      LoggerService.error('Failed to launch RCP URL: $fullUrl', e, s);
    }
  }
}
