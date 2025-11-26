// lib/features/explorer/widgets/search_results/group_result_card.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_colors.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_entity.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_badges.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// WHY: Widget for displaying a generic group search result card.
/// Extracted from DatabaseSearchView for better separation of concerns and testability.
class GroupResultCard extends StatelessWidget {
  const GroupResultCard({required this.group, super.key});

  final GenericGroupEntity group;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final accentColor = theme.colorScheme.princeps;
    final hasPrinciples = group.commonPrincipes.isNotEmpty;

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
                      const Gap(AppDimens.spacing2xs),
                      const GenericBadge(),
                      const Gap(AppDimens.spacingXs),
                      Expanded(
                        child: Text(
                          group.princepsReferenceName,
                          style: theme.textTheme.p.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Gap(AppDimens.spacingSm),
                  Text(
                    Strings.activePrinciplesLabel,
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(AppDimens.spacing2xs),
                  Text(
                    hasPrinciples
                        ? group.commonPrincipes
                        : Strings.notDetermined,
                    style: hasPrinciples
                        ? theme.textTheme.muted
                        : theme.textTheme.small,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(AppDimens.spacingSm),
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
