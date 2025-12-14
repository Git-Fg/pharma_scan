import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/features/explorer/domain/entities/cluster_entity.dart';

/// A tile representing a cluster (conceptual group) in search results
/// Displays cluster information and opens a drawer when tapped
class ClusterTile extends StatelessWidget {
  const ClusterTile({
    required this.entity,
    required this.onTap,
    super.key,
  });

  final ClusterEntity entity;
  final VoidCallback onTap; // Callback when tile is tapped (opens drawer)

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: Strings.clusterTileSemantics(entity.title, entity.productCount),
      hint: Strings.clusterTileHint,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spacingMd,
              vertical: AppDimens.spacingSm,
            ),
            decoration: BoxDecoration(
              color: context.colors.card,
              border: Border(
                bottom: BorderSide(color: context.colors.border),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entity.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typo.p.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (entity.subtitle.isNotEmpty) ...[
                        const Gap(4),
                        Text(
                          entity.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typo.small.copyWith(
                            color: context.colors.mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Gap(AppDimens.spacingSm),
                ShadBadge(
                  child: Text(Strings.productCount(entity.productCount)),
                ),
                const Gap(AppDimens.spacingSm),
                const ExcludeSemantics(
                  child: Icon(LucideIcons.chevronRight, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension Strings on String {
  static String clusterTileSemantics(String title, int productCount) {
    return 'Cluster $title, ${productCount.toString()} produits';
  }

  static String get clusterTileHint => 'Ouvrir les détails';

  static String productCount(int count) {
    return '$count produits';
  }
}
