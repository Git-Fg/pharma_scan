import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:azlistview/azlistview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/medicament_tile.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/molecule_group_tile.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double explorerListItemHeight = 108;

class ExplorerContentList extends ConsumerWidget {
  const ExplorerContentList({
    required this.groups,
    required this.groupedItems,
    required this.searchResults,
    required this.hasSearchText,
    required this.isSearching,
    required this.currentQuery,
    this.bottomPadding = 0,
    this.itemScrollController,
    this.itemPositionsListener,
    super.key,
  });

  final AsyncValue<GenericGroupsState> groups;
  final List<GenericGroupEntity> groupedItems;
  final AsyncValue<List<SearchResultItem>> searchResults;
  final bool hasSearchText;
  final bool isSearching;
  final String currentQuery;
  final double bottomPadding;
  final ItemScrollController? itemScrollController;
  final ItemPositionsListener? itemPositionsListener;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldShowSearch = hasSearchText && isSearching;
    final content = shouldShowSearch
        ? searchResults.when(
            skipLoadingOnReload: true,
            data: (items) => _buildSearchResultsList(context, ref, items),
            loading: () => _buildSkeletonList(context),
            error: (error, _) =>
                _buildSearchError(context, ref, error, currentQuery),
          )
        : _buildGenericGroupsList(context, ref, groups);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
      child: content,
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

  Widget _buildExplorerEmptyState(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(
        top: AppDimens.spacingLg,
        bottom: AppDimens.spacingXl,
      ),
      child: StatusView(
        type: StatusType.empty,
        title: Strings.explorerEmptyTitle,
        description: Strings.explorerEmptyDescription,
      ),
    );
  }

  /// Formats principles string for display by capitalizing the first letter.
  /// Example: "PARACETAMOL" -> "Paracetamol", "PARACETAMOL, CODEINE" -> "Paracetamol, Codeine"
  String _formatPrinciples(String principles) {
    if (principles.isEmpty) return principles;
    return principles
        .split(',')
        .map((p) {
          final trimmed = p.trim();
          if (trimmed.isEmpty) return trimmed;
          return trimmed[0].toUpperCase() +
              (trimmed.length > 1 ? trimmed.substring(1).toLowerCase() : '');
        })
        .where((p) => p.isNotEmpty)
        .join(', ');
  }

  Widget _buildGenericGroupTile(
    BuildContext context,
    GenericGroupEntity group,
  ) {
    final hasPrinciples = group.commonPrincipes.isNotEmpty;
    final principles = hasPrinciples
        ? _formatPrinciples(group.commonPrincipes)
        : Strings.notDetermined;
    final brand = group.princepsReferenceName.isNotEmpty
        ? group.princepsReferenceName
        : Strings.notDetermined;
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: '$principles, référence $brand',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => AutoRouter.of(context).push(
            GroupExplorerRoute(groupId: group.groupId.toString()),
          ),
          child: SizedBox(
            height: explorerListItemHeight,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingMd,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.shadColors.border),
                ),
              ),
              child: Row(
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          principles,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.shadTextTheme.p.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          brand,
                          maxLines: 1,
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
      ),
    );
  }

  Widget _buildGenericGroupsList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<GenericGroupsState> groups,
  ) {
    if (groups.isLoading) {
      return _buildSkeletonList(context);
    }

    final data = groups.asData?.value;
    if (groups.hasError && (data == null || data.items.isEmpty)) {
      return _buildGroupsError(context, ref);
    }
    if (data == null || data.items.isEmpty || groupedItems.isEmpty) {
      return _buildExplorerEmptyState(context);
    }

    final items = _buildSuspensionItems(groupedItems);
    if (items.isEmpty) {
      return _buildExplorerEmptyState(context);
    }

    SuspensionUtil.setShowSuspensionStatus(items);
    final indexTags = SuspensionUtil.getTagIndexList(items);

    return AzListView(
      data: items,
      itemCount: items.length,
      itemScrollController: itemScrollController,
      itemPositionsListener: itemPositionsListener,
      padding: EdgeInsets.only(
        top: AppDimens.spacing2xs,
        bottom: bottomPadding,
      ),
      susItemHeight: 32,
      susItemBuilder: (context, index) =>
          _buildSuspensionHeader(context, items[index]),
      itemBuilder: (context, index) =>
          _buildGroupedListItem(context, items[index].payload),
      indexBarData: indexTags,
      indexBarMargin: EdgeInsets.only(bottom: bottomPadding),
      indexBarOptions: _buildIndexBarOptions(context),
      indexHintBuilder: _buildIndexHint,
    );
  }

  Widget _buildSuspensionHeader(
    BuildContext context,
    ISuspensionBean item,
  ) {
    if (!item.isShowSuspension) return const SizedBox.shrink();
    final label = item.getSuspensionTag();

    return Container(
      height: 32,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
      decoration: BoxDecoration(
        color: context.shadColors.muted,
        border: Border(
          bottom: BorderSide(color: context.shadColors.border),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: context.shadTextTheme.small.copyWith(
          color: context.shadColors.mutedForeground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildGroupedListItem(BuildContext context, GenericGroupEntity item) {
    return _buildGenericGroupTile(context, item);
  }

  Widget _buildSkeletonList(BuildContext context) {
    final placeholderColor = context.shadColors.muted.withValues(
      alpha: 0.3,
    );
    return ListView.separated(
      padding: EdgeInsets.only(
        bottom: bottomPadding,
        top: AppDimens.spacing2xs,
      ),
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
  }

  Widget _buildSearchResultsList(
    BuildContext context,
    WidgetRef ref,
    List<SearchResultItem> results,
  ) {
    if (results.isEmpty) {
      final filters = ref.read(searchFiltersProvider);
      final hasFilters = filters.hasActiveFilters;

      return Padding(
        padding: EdgeInsets.only(
          top: AppDimens.spacing2xl,
          bottom: bottomPadding + AppDimens.spacing2xl,
        ),
        child: StatusView(
          type: StatusType.empty,
          title: Strings.noResults,
          description: hasFilters ? Strings.filters : null,
          actionLabel: hasFilters ? Strings.clearFilters : null,
          onAction: hasFilters
              ? ref.read(searchFiltersProvider.notifier).clearFilters
              : null,
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: bottomPadding,
        top: AppDimens.spacing2xs,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];

        if (result is ClusterResult) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing2xs),
            child: MoleculeGroupTile(
              moleculeName: result.displayName,
              princepsName: result.sortKey.isNotEmpty
                  ? result.sortKey
                  : (result.displayName.isNotEmpty
                        ? result.displayName
                        : Strings.notDetermined),
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
      },
    );
  }

  Widget _buildSearchError(
    BuildContext context,
    WidgetRef ref,
    Object error,
    String currentQuery,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
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
    // Principles are already normalized from the database
    final sanitizedPrinciples = summary.data.principesActifsCommuns;

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
                value: (sanitizedPrinciples?.isNotEmpty ?? false)
                    ? _parseAndJoinPrinciplesFromJson(sanitizedPrinciples!)
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
              if (summary.formePharmaceutique.isNotEmpty) ...[
                const Gap(AppDimens.spacingMd),
                buildDetailItem(
                  context,
                  label: Strings.pharmaceuticalFormLabel,
                  value: summary.formePharmaceutique,
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

  List<_ExplorerListItem> _buildSuspensionItems(
    List<GenericGroupEntity> items,
  ) {
    return items
        .map(
          (item) => _ExplorerListItem(
            payload: item,
            tag: item.getSuspensionTag(),
          ),
        )
        .toList();
  }

  IndexBarOptions _buildIndexBarOptions(BuildContext context) {
    final theme = context.shadTheme;
    return IndexBarOptions(
      needRebuild: true,
      textStyle: theme.textTheme.small.copyWith(
        color: theme.colorScheme.mutedForeground,
      ),
      selectTextStyle: theme.textTheme.small.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
      selectItemDecoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
      ),
      indexHintDecoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: theme.radius,
        border: Border.all(color: theme.colorScheme.border),
      ),
      indexHintTextStyle: theme.textTheme.h4.copyWith(
        color: theme.colorScheme.foreground,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildIndexHint(BuildContext context, String tag) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.shadColors.card,
        borderRadius: context.shadTheme.radius,
        border: Border.all(color: context.shadColors.border),
      ),
      child: Text(
        tag,
        style: context.shadTextTheme.h4.copyWith(
          color: context.shadColors.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _parseAndJoinPrinciplesFromJson(String jsonStr) {
    try {
      final decoded = json.decode(jsonStr);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).join(', ');
      }
    } on FormatException {
      // If parsing fails, return the original string
      return jsonStr;
    }
    // If it's not a list, return as is
    return jsonStr;
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

class _ExplorerListItem extends ISuspensionBean {
  _ExplorerListItem({required this.payload, required this.tag});

  final GenericGroupEntity payload;
  final String tag;

  @override
  String getSuspensionTag() => tag;
}
