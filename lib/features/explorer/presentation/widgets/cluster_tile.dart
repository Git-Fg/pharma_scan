import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/ui/theme/app_theme.dart';
import 'package:pharma_scan/core/domain/entities/cluster_entity.dart';

/// A tile representing a cluster (conceptual group) in search results
/// Displays cluster information and opens a drawer when tapped
class ClusterTile extends StatelessWidget {
  const ClusterTile({required this.entity, required this.onTap, super.key});

  final ClusterEntity entity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = entity.productCount;
    final countText = Strings.productCount(count);

    return Semantics(
      label: Strings.clusterTileSemantics(entity.title, count),
      hint: Strings.clusterTileHint,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          highlightColor: context.colors.accent.withValues(alpha: 0.1),
          splashColor: context.colors.accent.withValues(alpha: 0.05),
          child: Container(
            width: double.infinity,
            padding: const .symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: context.colors.card,
              border: Border(
                bottom: BorderSide(
                  color: context.colors.border.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      Text(
                        entity.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typo.p.copyWith(
                          fontWeight: .w600,
                          height: 1.2,
                        ),
                      ),
                      if (entity.subtitle.isNotEmpty &&
                          entity.subtitle != entity.title)
                        Text(
                          entity.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typo.small.copyWith(
                            color: context.colors.mutedForeground,
                            height: 1.2,
                          ),
                        ),
                    ],
                  ),
                ),
                const Gap(12),
                Container(
                  padding: const .symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.actionPrimary.withValues(alpha: 0.1),
                        context.actionPrimary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: context.actionPrimary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    countText,
                    style: context.typo.small.copyWith(
                      color: context.actionPrimary,
                      fontWeight: .w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Gap(8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: context.colors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: Colors.grey,
                  ),
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
