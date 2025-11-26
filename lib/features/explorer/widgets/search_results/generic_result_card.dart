// lib/features/explorer/widgets/search_results/generic_result_card.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/theme/app_colors.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_badges.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    final theme = ShadTheme.of(context);
    final accentColor = theme.colorScheme.generic;
    final sanitizedPrinciples = generic.principesActifsCommuns
        .map(sanitizeActivePrinciple)
        .where((element) => element.isNotEmpty)
        .toList();
    final details = [
      if (generic.formePharmaceutique?.isNotEmpty ?? false)
        generic.formePharmaceutique!,
      if (sanitizedPrinciples.isNotEmpty) sanitizedPrinciples.join(' + '),
    ].join(' • ');

    return ShadCard(
      padding: EdgeInsets.zero,
      backgroundColor: theme.colorScheme.background,
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
                          style: theme.textTheme.p.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                  if (details.isNotEmpty) ...[
                    const Gap(AppDimens.spacing2xs),
                    Text(
                      details,
                      style: theme.textTheme.muted,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const Gap(AppDimens.spacingSm),
                  Text(
                    Strings.princepsCount(princeps.length),
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(AppDimens.spacing2xs),
                  ...princeps.map(
                    (princepsItem) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        Strings.princepsSummaryItem(princepsItem.nomCanonique),
                        style: theme.textTheme.muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      LucideIcons.chevronRight,
                      size: AppDimens.iconSm,
                      color: theme.colorScheme.mutedForeground,
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
