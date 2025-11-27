// lib/features/explorer/widgets/search_results/group_result_card.dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_entity.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_badges.dart';
import 'package:forui/forui.dart';

/// WHY: Widget for displaying a generic group search result card.
/// Extracted from DatabaseSearchView for better separation of concerns and testability.
class GroupResultCard extends StatelessWidget {
  const GroupResultCard({required this.group, super.key});

  final GenericGroupEntity group;

  @override
  Widget build(BuildContext context) {
    final accentColor = context.theme.colors.secondary;
    final hasPrinciples = group.commonPrincipes.isNotEmpty;

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
                      const PrincepsBadge(),
                      const Gap(AppDimens.spacing2xs),
                      const GenericBadge(),
                      const Gap(AppDimens.spacingXs),
                      Expanded(
                        child: Text(
                          group.princepsReferenceName,
                          style: context.theme.typography.base,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Gap(AppDimens.spacingSm),
                  Text(
                    Strings.activePrinciplesLabel,
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                  const Gap(AppDimens.spacing2xs),
                  Text(
                    hasPrinciples
                        ? group.commonPrincipes
                        : Strings.notDetermined,
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Gap(AppDimens.spacingSm),
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
