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
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/logic/grouping_algorithms.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/medicament_tile.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/molecule_group_tile.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ExplorerContentList extends ConsumerWidget {
  const ExplorerContentList({
    required this.groups,
    required this.groupedItems,
    required this.searchResults,
    required this.hasSearchText,
    required this.isSearching,
    required this.currentQuery,
    this.controller,
    super.key,
  });

  final AutoScrollController? controller;
  final AsyncValue<GenericGroupsState> groups;
  final List<Object> groupedItems;
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
          const SliverGap(AppDimens.spacingMd),
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
    return formatPrinciples(principles);
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => AutoRouter.of(context).push(
            GroupExplorerRoute(groupId: group.groupId.toString()),
          ),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppDimens.listTileMinHeight,
            ),
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
                Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: context.shadColors.border,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    Strings.generics.substring(0, 1),
                    style: context.shadTextTheme.small,
                  ),
                ),
                const Gap(AppDimens.spacingSm),
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
                      const Gap(4),
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
                const Gap(AppDimens.spacingXs),
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
        sliver = SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final item = groupedItems[index];
            Widget content;
            if (item is GenericGroupEntity) {
              content = Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimens.spacing2xs,
                ),
                child: _buildGenericGroupTile(context, item),
              );
            } else if (item is GroupCluster) {
              content = Padding(
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
              final firstItem = item.first;
              final moleculeName = firstItem.commonPrincipes.isNotEmpty
                  ? _formatPrinciples(firstItem.commonPrincipes)
                  : (firstItem.princepsReferenceName.isNotEmpty
                        ? firstItem.princepsReferenceName
                        : Strings.notDetermined);
              content = Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimens.spacing2xs,
                ),
                child: MoleculeGroupTile(
                  moleculeName: moleculeName,
                  groups: item,
                  itemBuilder: _buildGenericGroupTile,
                ),
              );
            } else {
              return const SizedBox.shrink();
            }

            if (controller != null) {
              return AutoScrollTag(
                key: ValueKey(index),
                controller: controller!,
                index: index,
                child: content,
              );
            }

            return content;
          }, childCount: groupedItems.length),
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
                    const Gap(AppDimens.spacingSm),
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
                          const Gap(4),
                          _SkeletonBlock(
                            height: 14,
                            width: 150,
                            color: placeholderColor,
                          ),
                        ],
                      ),
                    ),
                    const Gap(AppDimens.spacingXs),
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
          padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing2xl),
          child: StatusView(
            type: StatusType.empty,
            title: Strings.noResults,
            description: hasFilters ? Strings.filters : null,
            actionLabel: hasFilters ? Strings.clearFilters : null,
            onAction: hasFilters
                ? ref.read(searchFiltersProvider.notifier).clearFilters
                : null,
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
            currentQuery: currentQuery,
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
          AutoRouter.of(context).push(
            GroupExplorerRoute(groupId: group.groupId.toString()),
          ),
        );
      case PrincepsResult(groupId: final groupId):
        unawaited(
          AutoRouter.of(context).push(
            GroupExplorerRoute(groupId: groupId.toString()),
          ),
        );
      case GenericResult(groupId: final groupId):
        unawaited(
          AutoRouter.of(context).push(
            GroupExplorerRoute(groupId: groupId.toString()),
          ),
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
    final heroTag = 'standalone-$representativeCip';
    final sanitizedPrinciples = summary.data.principesActifsCommuns
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

    Widget buildDetailItem(
      BuildContext context, {
      required String label,
      required String value,
      bool copyable = false,
      String? copyLabel,
      VoidCallback? onCopy,
    }) {
      final theme = context.shadTheme;
      final mutedForeground = theme.colorScheme.mutedForeground;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.small.copyWith(color: mutedForeground),
          ),
          const Gap(AppDimens.spacing2xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: theme.textTheme.p,
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (copyable && onCopy != null) ...[
                const Gap(AppDimens.spacingXs),
                Semantics(
                  button: true,
                  label: copyLabel ?? Strings.copyToClipboard,
                  hint: Strings.copyToClipboard,
                  child: ShadIconButton.ghost(
                    icon: const Icon(LucideIcons.copy, size: 16),
                    onPressed: onCopy,
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    }

    return ShadSheet(
      title: const Text(Strings.medicationDetails),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: heroTag,
                child: Material(
                  type: MaterialType.transparency,
                  child: buildDetailItem(
                    context,
                    label: Strings.nameLabel,
                    value: summary.data.nomCanonique,
                    copyable: true,
                    copyLabel: Strings.copyNameLabel,
                    onCopy: () => copyToClipboard(
                      summary.data.nomCanonique,
                      Strings.copyNameLabel,
                    ),
                  ),
                ),
              ),
              const Gap(AppDimens.spacingMd),
              buildDetailItem(
                context,
                label: Strings.activePrinciplesLabel,
                value: sanitizedPrinciples.isNotEmpty
                    ? sanitizedPrinciples.join(', ')
                    : Strings.notDetermined,
              ),
              const Gap(AppDimens.spacingMd),
              buildDetailItem(
                context,
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
                buildDetailItem(
                  context,
                  label: Strings.holder,
                  value: summary.titulaire!,
                ),
              ],
              if (summary.data.formePharmaceutique != null &&
                  summary.data.formePharmaceutique!.isNotEmpty) ...[
                const Gap(AppDimens.spacingMd),
                buildDetailItem(
                  context,
                  label: Strings.pharmaceuticalFormLabel,
                  value: summary.data.formePharmaceutique!,
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
