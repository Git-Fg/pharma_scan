import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/formatters.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_badges.dart';
import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/view_group_detail_extensions.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PrincepsHeroCard extends StatelessWidget {
  const PrincepsHeroCard({
    required this.princeps,
    required this.onViewDetails,
    this.isFallbackGeneric = false,
    super.key,
  });

  final GroupDetailEntity princeps;
  final VoidCallback onViewDetails;
  final bool isFallbackGeneric;

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    final priceText = princeps.prixPublic != null
        ? formatEuro(princeps.prixPublic!)
        : Strings.priceUnavailable;
    final refundText = princeps.trimmedRefundRate ?? Strings.refundNotAvailable;
    final labDisplay = princeps.parsedTitulaire.isEmpty
        ? Strings.unknownHolder
        : princeps.parsedTitulaire;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary),
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: theme.radius,
      ),
      child: ShadCard(
        padding: const EdgeInsets.all(AppDimens.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFallbackGeneric) ...[
              ShadBadge.secondary(
                child: Text(
                  Strings.heroFallbackGeneric,
                  style: theme.textTheme.small,
                ),
              ),
              const Gap(AppDimens.spacing2xs),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        princeps.displayName,
                        style: theme.textTheme.h3.copyWith(
                          color: theme.colorScheme.foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Gap(AppDimens.spacing2xs),
                      Text(
                        '${Strings.cip} ${princeps.codeCip}',
                        style: theme.textTheme.small.copyWith(
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                      const Gap(4),
                      Text(
                        '${Strings.laboratoryLabel}: $labDisplay',
                        style: theme.textTheme.small.copyWith(
                          color: theme.colorScheme.mutedForeground,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Gap(AppDimens.spacingSm),
                ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: onViewDetails,
                  leading: const Icon(LucideIcons.info, size: 16),
                  child: const Text(Strings.showMedicamentDetails),
                ),
              ],
            ),
            const Gap(AppDimens.spacingSm),
            FinancialBadge(
              refundRate: princeps.trimmedRefundRate,
              price: princeps.prixPublic,
            ),
            const Gap(AppDimens.spacing2xs),
            Row(
              children: [
                Expanded(
                  child: _buildStatChip(
                    context,
                    label: Strings.priceShort,
                    value: priceText,
                    icon: LucideIcons.banknote,
                  ),
                ),
                const Gap(AppDimens.spacingSm),
                Expanded(
                  child: _buildStatChip(
                    context,
                    label: Strings.refundShort,
                    value: refundText,
                    icon: LucideIcons.percent,
                  ),
                ),
              ],
            ),
            const Gap(AppDimens.spacingSm),
            RegulatoryBadges(
              isNarcotic: princeps.isNarcotic,
              isList1: princeps.isList1,
              isList2: princeps.isList2,
              isException: princeps.isException,
              isRestricted: princeps.isRestricted,
              isHospitalOnly: princeps.isHospitalOnly,
              isDental: princeps.isDental,
              isSurveillance: princeps.isSurveillance,
              isOtc: princeps.isOtc,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    final theme = context.shadTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingSm,
        vertical: AppDimens.spacing2xs,
      ),
      decoration: BoxDecoration(
        borderRadius: theme.radius,
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.mutedForeground,
          ),
          const Gap(6),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
