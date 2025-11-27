// lib/features/explorer/widgets/search_results/generic_result_card.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_badges.dart';
import 'package:forui/forui.dart';

/// WHY: Widget for displaying a generic search result card with princeps count.
/// Extracted from DatabaseSearchView for better separation of concerns and testability.
class GenericResultCard extends StatelessWidget {
  const GenericResultCard({
    required this.generic,
    required this.princeps,
    super.key,
  });

  final MedicamentSummaryData generic;
  final List<MedicamentSummaryData> princeps;

  @override
  Widget build(BuildContext context) {
    final accentColor = context.theme.colors.primary;
    final sanitizedPrinciples = generic.principesActifsCommuns
        .map(sanitizeActivePrinciple)
        .where((element) => element.isNotEmpty)
        .toList();
    final details = [
      if (generic.formePharmaceutique?.isNotEmpty ?? false)
        generic.formePharmaceutique!,
      if (sanitizedPrinciples.isNotEmpty) sanitizedPrinciples.join(' + '),
    ].join(' • ');

    return FCard.raw(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const GenericBadge(),
                      const Gap(AppDimens.spacingXs),
                      Expanded(
                        child: Text(
                          generic.nomCanonique,
                          style: context.theme.typography.base,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (details.isNotEmpty) ...[
                    const Gap(AppDimens.spacing2xs),
                    Text(
                      details,
                      style: context.theme.typography.sm.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const Gap(AppDimens.spacingSm),
                  Text(
                    Strings.princepsCount(princeps.length),
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                  const Gap(AppDimens.spacing2xs),
                  ...princeps.map(
                    (princepsItem) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        Strings.princepsSummaryItem(princepsItem.nomCanonique),
                        style: context.theme.typography.sm.copyWith(
                          color: context.theme.colors.mutedForeground,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      FIcons.chevronRight,
                      size: AppDimens.iconSm,
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
