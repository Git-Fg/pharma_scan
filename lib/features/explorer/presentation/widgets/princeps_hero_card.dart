import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/formatters.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_badges.dart';
import 'package:pharma_scan/core/widgets/ui_kit/stat_chip.dart';
import 'package:pharma_scan/core/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/core/domain/extensions/medication_status_extensions.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/view_group_detail_extensions.dart';
import 'package:pharma_scan/core/widgets/badges/status_badges.dart';
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
    final statusFlags = princeps.statusFlags(
      availabilityStatus: princeps.trimmedAvailabilityStatus,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.primary),
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: theme.radius,
      ),
      child: ShadCard(
        padding: const .all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFallbackGeneric) ...[
              ShadBadge.secondary(child: Text(Strings.heroFallbackGeneric)),
              const Gap(4),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  princeps.displayName,
                  style: theme.textTheme.h3.copyWith(
                    color: theme.colorScheme.foreground,
                    fontWeight: .w700,
                  ),
                  softWrap: true,
                ),
                const Gap(4),
                Text(
                  '${Strings.cip} ${princeps.cipCode}',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
                const Gap(4),
                Text(
                  '${Strings.laboratoryLabel}: $labDisplay',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                    fontWeight: .w600,
                  ),
                  softWrap: true,
                ),
                const Gap(12),
                ShadButton.outline(
                  onPressed: onViewDetails,
                  child: const Icon(LucideIcons.info),
                ),
              ],
            ),
            const Gap(12),
            Row(
              children: [
                Expanded(
                  child: StatChip(
                    label: Strings.priceShort,
                    value: priceText,
                    icon: LucideIcons.banknote,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: StatChip(
                    label: Strings.refundShort,
                    value: refundText,
                    icon: LucideIcons.percent,
                  ),
                ),
              ],
            ),
            const Gap(12),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                ...buildStatusBadges(
                  context,
                  statusFlags,
                  availabilityStatus: princeps.trimmedAvailabilityStatus,
                ),
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
          ],
        ),
      ),
    );
  }
}
