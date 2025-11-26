// lib/features/explorer/widgets/search_results/princeps_result_card.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/theme/app_colors.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_badges.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// WHY: Widget for displaying a princeps search result card with generic count.
/// Extracted from DatabaseSearchView for better separation of concerns and testability.
class PrincepsResultCard extends StatelessWidget {
  const PrincepsResultCard({
    required this.princeps,
    required this.generics,
    super.key,
  });

  final MedicamentSummaryData princeps;
  final List<MedicamentSummaryData> generics;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final accentColor = theme.colorScheme.princeps;
    // WHY: Summarize generics by name (similar to summarizeGenericsByName but for MedicamentSummaryData)
    final counts = <String, int>{};
    for (final generic in generics) {
      final name = generic.nomCanonique;
      if (name.isEmpty) continue;
      counts.update(name, (value) => value + 1, ifAbsent: () => 1);
    }
    final summarizedGenerics = counts.entries.toList()
      ..sort((a, b) {
        final countComparison = b.value.compareTo(a.value);
        if (countComparison != 0) return countComparison;
        return a.key.compareTo(b.key);
      });

    final details = [
      if (princeps.formePharmaceutique?.isNotEmpty ?? false)
        princeps.formePharmaceutique!,
      if (princeps.principesActifsCommuns.isNotEmpty)
        princeps.principesActifsCommuns
            .map(sanitizeActivePrinciple)
            .where((element) => element.isNotEmpty)
            .join(' + '),
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
                      const PrincepsBadge(),
                      const Gap(AppDimens.spacingXs),
                      Expanded(
                        child: Text(
                          princeps.nomCanonique,
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
                    Strings.genericCount(generics.length),
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(AppDimens.spacing2xs),
                  ...summarizedGenerics.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        Strings.genericSummaryItem(entry.key, entry.value),
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
