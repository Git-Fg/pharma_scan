import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/detail_item.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/logic/explorer_grouping_helper.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/medicament_tile.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/molecule_group_tile.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Wrapper class to hold a cluster of groups with the same commonPrincipes.
class _GroupCluster {
  const _GroupCluster({
    required this.groups,
    required this.commonPrincipes,
    required this.displayName,
  });

  final List<GenericGroupEntity> groups;
  final String commonPrincipes; // Original principles for internal use
  final String displayName; // Formatted display name for UI
}

class ExplorerContentList extends ConsumerWidget {
  const ExplorerContentList({
    required this.databaseStats,
    required this.groups,
    required this.searchResults,
    required this.hasSearchText,
    required this.isSearching,
    required this.currentQuery,
    super.key,
  });

  final AsyncValue<Map<String, dynamic>> databaseStats;
  final AsyncValue<GenericGroupsState> groups;
  final AsyncValue<List<SearchResultItem>> searchResults;
  final bool hasSearchText;
  final bool isSearching;
  final String currentQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
      sliver: SliverMainAxisGroup(
        slivers: [
          // Stats header
          databaseStats.when(
            data: (stats) => SliverToBoxAdapter(
              child: Column(
                children: [
                  const Gap(AppDimens.spacing2xs),
                  _buildStatsHeader(context, stats),
                  const Gap(AppDimens.spacingMd),
                ],
              ),
            ),
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          // Variable content (Groups vs Search)
          if (!hasSearchText)
            _buildGenericGroupsSliver(context, ref, groups)
          else if (!isSearching)
            _buildSkeletonSliver(context)
          else
            searchResults.when(
              skipLoadingOnReload: true,
              data: (items) => _buildSearchResultsSliver(context, ref, items),
              loading: () => _buildSkeletonSliver(context),
              error: (error, _) =>
                  _buildSearchErrorSliver(context, ref, error, currentQuery),
            ),
          // Final spacing
          const SliverGap(AppDimens.spacingMd),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(BuildContext context, Map<String, dynamic> stats) {
    final statsConfig = [
      (LucideIcons.star, Strings.totalPrinceps, '${stats['total_princeps']}'),
      (LucideIcons.pill, Strings.totalGenerics, '${stats['total_generiques']}'),
      (
        LucideIcons.activity,
        Strings.totalPrinciples,
        '${stats['total_principes']}',
      ),
    ];

    final breakpoint = context.breakpoint;
    final isSmallScreen = breakpoint < context.shadTheme.breakpoints.sm;
    final iconSize = isSmallScreen ? AppDimens.iconSm : AppDimens.iconMd;
    final theme = context.shadTheme;
    final valueTextStyle = isSmallScreen
        ? theme.textTheme.h3
        : theme.textTheme.h4;
    final labelTextStyle = isSmallScreen
        ? theme.textTheme.small
        : theme.textTheme.p;

    return ShadCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimens.spacingXs,
          horizontal: AppDimens.spacingSm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final config in statsConfig)
              Expanded(
                child: _buildStatItem(
                  context,
                  icon: config.$1,
                  label: config.$2,
                  value: config.$3,
                  iconSize: iconSize,
                  valueTextStyle: valueTextStyle,
                  labelTextStyle: labelTextStyle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required double iconSize,
    required TextStyle valueTextStyle,
    required TextStyle labelTextStyle,
  }) {
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(
              icon,
              size: iconSize,
              color: context.shadColors.primary,
            ),
          ),
          const Gap(AppDimens.spacing2xs),
          Text(
            value,
            style: valueTextStyle.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Gap(AppDimens.spacing2xs),
          Flexible(
            child: Text(
              label,
              style: labelTextStyle.copyWith(
                color: context.shadColors.mutedForeground,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsError(BuildContext context, WidgetRef ref) {
    return StatusView(
      type: StatusType.error,
      title: Strings.loadingError,
      description: Strings.errorLoadingGroups,
      action: Semantics(
        button: true,
        label: Strings.retryLoadingGroups,
        child: ShadButton(
          onPressed: () => ref.invalidate(genericGroupsProvider),
          child: const Text(Strings.retry),
        ),
      ),
    );
  }

  /// Formats principles string for display by capitalizing the first letter.
  /// Example: "PARACETAMOL" -> "Paracetamol", "PARACETAMOL, CODEINE" -> "Paracetamol, Codeine"
  String _formatPrinciples(String principles) {
    return ExplorerGroupingHelper.formatPrinciples(principles);
  }

  /// Groups all items by their commonPrincipes using a 2-pass algorithm:
  /// 1. Cluster: Group items only when safe (valid principles), otherwise keep unique
  /// 2. Label & Sort: Determine visible labels, then sort by those labels
  ///
  /// Returns a sorted list where each element is either:
  /// - A single `GenericGroupEntity` (if count == 1 for that grouping key)
  /// - A `_GroupCluster` (if count > 1) containing all groups with the same principles
  List<Object> _groupByCommonPrincipes(List<GenericGroupEntity> items) {
    // Delegate to the testable helper, then convert GroupCluster to _GroupCluster
    final result = ExplorerGroupingHelper.groupByCommonPrincipes(items);

    // Convert public GroupCluster back to private _GroupCluster for internal use
    return result.map((item) {
      if (item is GroupCluster) {
        return _GroupCluster(
          groups: item.groups,
          commonPrincipes: item.commonPrincipes,
          displayName: item.displayName,
        );
      }
      return item;
    }).toList();
  }

  Widget _buildGenericGroupTile(
    BuildContext context,
    GenericGroupEntity group,
  ) {
    final hasPrinciples = group.commonPrincipes.isNotEmpty;
    final principles = hasPrinciples
        ? _formatPrinciples(group.commonPrincipes)
        : Strings.notDetermined;
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: '$principles, référence ${group.princepsReferenceName}',
        child: InkWell(
          onTap: () => context.router.push(
            GroupExplorerRoute(groupId: group.groupId.toString()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spacingMd,
              vertical: AppDimens.spacingSm,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.shadColors.border),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShadBadge.outline(
                  child: Text(
                    Strings.generics.substring(0, 1),
                    style: context.shadTextTheme.small,
                  ),
                ),
                const SizedBox(width: AppDimens.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        principles,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.shadTextTheme.p.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group.princepsReferenceName,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.shadTextTheme.small.copyWith(
                          color: context.shadColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.spacingXs),
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

  // Sliver versions for CustomScrollView
  Widget _buildGenericGroupsSliver(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<GenericGroupsState> groups,
  ) {
    Widget sliver;
    if (groups.isLoading) {
      sliver = _buildSkeletonSliver(context);
    } else {
      final data = groups.asData?.value;
      if (groups.hasError && (data == null || data.items.isEmpty)) {
        sliver = SliverToBoxAdapter(
          child: _buildGroupsError(context, ref),
        );
      } else if (data == null || data.items.isEmpty) {
        sliver = const SliverToBoxAdapter(
          child: StatusView(type: StatusType.empty, title: Strings.noResults),
        );
      } else {
        final groupedItems = _groupByCommonPrincipes(data.items);
        final itemCount = groupedItems.length + (data.isLoadingMore ? 1 : 0);
        sliver = SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index == groupedItems.length) {
              return const Padding(
                padding: EdgeInsets.all(AppDimens.spacingMd),
                child: Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final item = groupedItems[index];
            if (item is GenericGroupEntity) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimens.spacing2xs,
                ),
                child: _buildGenericGroupTile(context, item),
              );
            } else if (item is _GroupCluster) {
              // Use displayName from cluster (formatted for display)
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimens.spacing2xs,
                ),
                child: MoleculeGroupTile(
                  moleculeName: item.displayName,
                  groups: item.groups,
                  itemBuilder: _buildGenericGroupTile,
                ),
              );
            } else if (item is List<GenericGroupEntity>) {
              // Legacy support for direct lists (shouldn't happen with new logic)
              final firstItem = item.first;
              final moleculeName = firstItem.commonPrincipes.isNotEmpty
                  ? _formatPrinciples(firstItem.commonPrincipes)
                  : (firstItem.princepsReferenceName.isNotEmpty
                        ? firstItem.princepsReferenceName
                        : Strings.notDetermined);
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimens.spacing2xs,
                ),
                child: MoleculeGroupTile(
                  moleculeName: moleculeName,
                  groups: item,
                  itemBuilder: _buildGenericGroupTile,
                ),
              );
            }
            return const SizedBox.shrink();
          }, childCount: itemCount),
        );
      }
    }
    return sliver;
  }

  Widget _buildSkeletonSliver(BuildContext context) {
    return Builder(
      builder: (context) {
        final placeholderColor = context.shadColors.muted.withValues(
          alpha: 0.3,
        );
        return SliverList.separated(
          itemCount: 4,
          separatorBuilder: (context, index) => const Gap(AppDimens.spacing2xs),
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimens.spacing2xs,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingMd,
                  vertical: AppDimens.spacingSm,
                ),
                child: Row(
                  children: [
                    _SkeletonBlock(
                      height: 20,
                      width: 20,
                      color: placeholderColor,
                    ),
                    const SizedBox(width: AppDimens.spacingSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SkeletonBlock(
                            height: 16,
                            width: 200,
                            color: placeholderColor,
                          ),
                          const SizedBox(height: 4),
                          _SkeletonBlock(
                            height: 14,
                            width: 150,
                            color: placeholderColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimens.spacingXs),
                    ExcludeSemantics(
                      child: _SkeletonBlock(
                        height: 16,
                        width: 16,
                        color: placeholderColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResultsSliver(
    BuildContext context,
    WidgetRef ref,
    List<SearchResultItem> results,
  ) {
    if (results.isEmpty) {
      final filters = ref.read(searchFiltersProvider);
      final hasFilters = filters.hasActiveFilters;

      return SliverToBoxAdapter(
        child: Padding(
          // Vertical padding only, horizontal handled by Scaffold
          padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing2xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                Strings.noResults,
                style: context.shadTextTheme.small.copyWith(
                  color: context.shadColors.mutedForeground,
                ),
              ),
              if (hasFilters) ...[
                const Gap(AppDimens.spacingSm),
                Semantics(
                  button: true,
                  label: Strings.resetAllFilters,
                  child: ShadButton.outline(
                    onPressed: ref
                        .read(searchFiltersProvider.notifier)
                        .clearFilters,
                    child: const Text(Strings.clearFilters),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final result = results[index];

        if (result is ClusterResult) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing2xs),
            child: MoleculeGroupTile(
              moleculeName: result.displayName,
              groups: result.groups,
              itemBuilder: _buildGenericGroupTile,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing2xs),
          child: MedicamentTile(
            item: result,
            onTap: () => _handleSearchResultTap(context, result),
          ),
        );
      }, childCount: results.length),
    );
  }

  Widget _buildSearchErrorSliver(
    BuildContext context,
    WidgetRef ref,
    Object error,
    String currentQuery,
  ) {
    return SliverToBoxAdapter(
      child: StatusView(
        type: StatusType.error,
        title: Strings.searchErrorOccurred,
        description: error.toString(),
        action: ShadButton(
          onPressed: () => ref.invalidate(searchResultsProvider(currentQuery)),
          child: const Text(Strings.retry),
        ),
      ),
    );
  }

  void _handleSearchResultTap(BuildContext context, SearchResultItem result) {
    switch (result) {
      case ClusterResult():
        break;
      case GroupResult(group: final group):
        unawaited(
          context.router.push(
            GroupExplorerRoute(groupId: group.groupId.toString()),
          ),
        );
      case PrincepsResult(groupId: final groupId):
        unawaited(
          context.router.push(GroupExplorerRoute(groupId: groupId.toString())),
        );
      case GenericResult(groupId: final groupId):
        unawaited(
          context.router.push(GroupExplorerRoute(groupId: groupId.toString())),
        );
      case StandaloneResult(
        summary: final summary,
        representativeCip: final representativeCip,
      ):
        unawaited(
          showShadSheet<void>(
            context: context,
            side: ShadSheetSide.bottom,
            builder: (overlayContext) => _buildStandaloneDetailOverlay(
              overlayContext,
              summary,
              representativeCip,
            ),
          ),
        );
    }
  }

  Widget _buildStandaloneDetailOverlay(
    BuildContext context,
    MedicamentEntity summary,
    String representativeCip,
  ) {
    final sanitizedPrinciples = summary.principesActifsCommuns
        .map(normalizePrincipleOptimal)
        .toList();

    Future<void> copyToClipboard(String text, String label) async {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            title: const Text(Strings.copiedToClipboard),
            description: Text(label),
          ),
        );
      }
    }

    return ShadSheet(
      title: const Text(Strings.medicationDetails),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailItem(
                label: Strings.nameLabel,
                value: summary.nomCanonique,
                copyable: true,
                copyLabel: Strings.copyNameLabel,
                onCopy: () => copyToClipboard(
                  summary.nomCanonique,
                  Strings.copyNameLabel,
                ),
              ),
              if (sanitizedPrinciples.isNotEmpty) ...[
                const Gap(AppDimens.spacingMd),
                DetailItem(
                  label: Strings.activePrinciplesLabel,
                  value: sanitizedPrinciples.join(', '),
                ),
              ],
              const Gap(AppDimens.spacingMd),
              DetailItem(
                label: Strings.cip,
                value: representativeCip,
                copyable: true,
                copyLabel: Strings.copyCipLabel,
                onCopy: () => copyToClipboard(
                  representativeCip,
                  Strings.copyCipLabel,
                ),
              ),
              if (summary.titulaire != null &&
                  summary.titulaire!.isNotEmpty) ...[
                const Gap(AppDimens.spacingMd),
                DetailItem(label: Strings.holder, value: summary.titulaire!),
              ],
              if (summary.formePharmaceutique != null &&
                  summary.formePharmaceutique!.isNotEmpty) ...[
                const Gap(AppDimens.spacingMd),
                DetailItem(
                  label: Strings.pharmaceuticalFormLabel,
                  value: summary.formePharmaceutique!,
                ),
              ],
              const Gap(AppDimens.spacingMd),
              ShadBadge.outline(
                child: Text(
                  Strings.uniqueMedicationNoGroup,
                  style: context.shadTextTheme.small,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height, required this.color, this.width});

  final double height;
  final double? width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: context.shadTheme.radius,
      ),
    );
  }
}
