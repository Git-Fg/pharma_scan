// lib/features/explorer/screens/database_search_view.dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/adaptive_overlay.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/detail_item.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_sheet_layout.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/models/search_result_item_model.dart';
import 'package:pharma_scan/features/explorer/providers/database_stats_provider.dart';
import 'package:pharma_scan/features/explorer/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/providers/search_provider.dart';
import 'package:pharma_scan/features/explorer/widgets/explorer_search_bar.dart';
import 'package:pharma_scan/features/explorer/widgets/medicament_tile.dart';
import 'package:pharma_scan/features/explorer/widgets/molecule_group_tile.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DatabaseSearchView extends HookConsumerWidget {
  const DatabaseSearchView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final debouncedQuery = useState('');

    // WHY: Set up scroll listener for pagination using useEffect
    useEffect(() {
      void onScroll() {
        if (!scrollController.hasClients) return;
        // WHY: Don't trigger group pagination when user is searching
        // Search results are capped at 50 by FuzzyBolt, so pagination isn't needed
        if (debouncedQuery.value.isNotEmpty) {
          return;
        }
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200) {
          final groupsState = ref.read(genericGroupsProvider);
          final data = groupsState.value;
          if (data == null || !data.hasMore || data.isLoadingMore) {
            return;
          }
          ref.read(genericGroupsProvider.notifier).loadMore();
        }
      }

      scrollController.addListener(onScroll);
      return () => scrollController.removeListener(onScroll);
    }, [scrollController]);

    final groups = ref.watch(genericGroupsProvider);
    // WHY: Watch provider with debounced query to avoid rebuilds on every keystroke
    final currentQuery = debouncedQuery.value;
    final searchResults = ref.watch(searchResultsProvider(currentQuery));
    final databaseStats = ref.watch(databaseStatsProvider);
    final hasSearchText = currentQuery.isNotEmpty;
    final isSearching = hasSearchText;
    final initStepAsync = ref.watch(initializationStepProvider);

    // WHY: Show initialization placeholder if database is not ready
    // This prevents showing "No results" during initialization
    // Exclude error state so MainScreen error banner is visible
    final initStep = initStepAsync.value;
    if (initStep != null &&
        initStep != InitializationStep.ready &&
        initStep != InitializationStep.error) {
      return const Scaffold(
        body: Center(
          child: StatusView(
            type: StatusType.loading,
            icon: LucideIcons.loader,
            title: Strings.initializationInProgress,
            description: Strings.initializationDescription,
          ),
        ),
      );
    }

    // WHY: Search bar is now a sticky bottom bar using Stack overlay
    // Keyboard handling is done by outer MainScreen scaffold

    return Scaffold(
      resizeToAvoidBottomInset:
          false, // Outer MainScreen handles keyboard resizing
      body: Stack(
        children: [
          // Main scrollable content
          CustomScrollView(
            controller: scrollController,
            slivers: [
              // Main content (stats, groups, search results)
              _buildMainContentSlivers(
                context,
                ref,
                databaseStats,
                groups,
                searchResults,
                hasSearchText,
                isSearching,
                currentQuery,
              ),
              // WHY: Add bottom padding to prevent content from being hidden behind search bar
              // Includes search bar height plus safe area insets
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom:
                      AppDimens.searchBarHeaderHeight +
                      MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          ),
          // WHY: Sticky bottom search bar - positioned at bottom of screen
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: ExplorerSearchBar(
                onSearchChanged: (query) => debouncedQuery.value = query,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContentSlivers(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Map<String, dynamic>> databaseStats,
    AsyncValue<GenericGroupsState> groups,
    AsyncValue<List<SearchResultItem>> searchResults,
    bool hasSearchText,
    bool isSearching,
    String currentQuery,
  ) {
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
          // Contenu variable (Groupes vs Recherche)
          if (!hasSearchText)
            _buildGenericGroupsSliver(groups, ref)
          else if (!isSearching)
            _buildSkeletonSliver()
          else
            searchResults.when(
              skipLoadingOnReload: true,
              data: (items) => _buildSearchResultsSliver(context, items, ref),
              loading: _buildSkeletonSliver,
              error: (error, _) =>
                  _buildSearchErrorSliver(error, currentQuery, ref),
            ),
          // Espace final
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 360;
        final iconSize = isSmallScreen ? AppDimens.iconSm : AppDimens.iconMd;
        final theme = ShadTheme.of(context);
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
      },
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
      // WHY: Merge value and label so screen readers announce "X Princeps" as a single unit
      // instead of separate "X" and "Princeps" elements
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            // WHY: Icon is decorative and should not be announced by screen readers
            child: Icon(
              icon,
              size: iconSize,
              color: ShadTheme.of(context).colorScheme.primary,
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
                color: ShadTheme.of(context).colorScheme.mutedForeground,
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

  Widget _buildGroupsError(WidgetRef ref) {
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

  /// Groups consecutive items with identical commonPrincipes.
  /// Returns a list where each element is either:
  /// - A single `GenericGroupEntity` (if count == 1)
  /// - A `List<GenericGroupEntity>` (if count > 1)
  List<Object> _groupConsecutiveMolecules(List<GenericGroupEntity> items) {
    if (items.isEmpty) return [];

    final result = <Object>[];
    GenericGroupEntity? currentGroup;
    List<GenericGroupEntity>? currentCluster;

    for (final item in items) {
      final molecule = item.commonPrincipes;

      if (currentGroup == null || currentGroup.commonPrincipes != molecule) {
        // Start a new group
        if (currentCluster != null && currentCluster.length > 1) {
          result.add(currentCluster);
        } else if (currentGroup != null) {
          result.add(currentGroup);
        }

        currentGroup = item;
        currentCluster = null;
      } else {
        // Same molecule - add to cluster
        if (currentCluster == null) {
          // Convert single item to cluster
          currentCluster = [currentGroup, item];
          currentGroup = null;
        } else {
          currentCluster.add(item);
        }
      }
    }

    // Add the last group/cluster
    if (currentCluster != null && currentCluster.length > 1) {
      result.add(currentCluster);
    } else if (currentGroup != null) {
      result.add(currentGroup);
    }

    return result;
  }

  Widget _buildGenericGroupTile(
    BuildContext context,
    GenericGroupEntity group,
  ) {
    final hasPrinciples = group.commonPrincipes.isNotEmpty;
    final principles = hasPrinciples
        ? group.commonPrincipes
        : Strings.notDetermined;
    final theme = ShadTheme.of(context);

    return MergeSemantics(
      child: Semantics(
        button: true,
        label: '$principles, référence ${group.princepsReferenceName}',
        child: InkWell(
          onTap: () =>
              context.router.push(GroupExplorerRoute(groupId: group.groupId)),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spacingMd,
              vertical: AppDimens.spacingSm,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.border),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShadBadge.secondary(
                  child: Text(
                    Strings.generics.substring(0, 1),
                    style: theme.textTheme.small,
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
                        style: theme.textTheme.p.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group.princepsReferenceName,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.small.copyWith(
                          color: theme.colorScheme.mutedForeground,
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
    AsyncValue<GenericGroupsState> groups,
    WidgetRef ref,
  ) {
    Widget sliver;
    if (groups.isLoading) {
      sliver = _buildSkeletonSliver();
    } else {
      final data = groups.asData?.value;
      if (groups.hasError && (data == null || data.items.isEmpty)) {
        sliver = SliverToBoxAdapter(child: _buildGroupsError(ref));
      } else if (data == null || data.items.isEmpty) {
        sliver = const SliverToBoxAdapter(
          child: StatusView(type: StatusType.empty, title: Strings.noResults),
        );
      } else {
        final groupedItems = _groupConsecutiveMolecules(data.items);
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
            } else if (item is List<GenericGroupEntity>) {
              final moleculeName = item.first.commonPrincipes.isNotEmpty
                  ? item.first.commonPrincipes
                  : Strings.notDetermined;
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
    // SUPPRESSION DU SLIVER PADDING : On retourne directement le sliver
    // Les clés sont gérées directement dans les slivers si nécessaire
    return sliver;
  }

  Widget _buildSkeletonSliver() {
    return Builder(
      builder: (context) {
        final placeholderColor = ShadTheme.of(
          context,
        ).colorScheme.muted.withValues(alpha: 0.3);
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
    List<SearchResultItem> results,
    WidgetRef ref,
  ) {
    if (results.isEmpty) {
      final filters = ref.watch(searchFiltersProvider);
      final hasFilters = filters.hasActiveFilters;

      return SliverToBoxAdapter(
        child: Padding(
          // Padding vertical uniquement nécessaire, horizontal géré par Scaffold
          padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing2xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                Strings.noResults,
                style: ShadTheme.of(context).textTheme.small.copyWith(
                  color: ShadTheme.of(context).colorScheme.mutedForeground,
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

    // Plus de SliverPadding ici
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final result = results[index];
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
    Object error,
    String currentQuery,
    WidgetRef ref,
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
      case GroupResult(group: final group):
        context.router.push(GroupExplorerRoute(groupId: group.groupId));
      case PrincepsResult(groupId: final groupId):
        context.router.push(GroupExplorerRoute(groupId: groupId));
      case GenericResult(groupId: final groupId):
        context.router.push(GroupExplorerRoute(groupId: groupId));
      case StandaloneResult(
        summary: final summary,
        representativeCip: final representativeCip,
      ):
        showAdaptiveSheet<void>(
          context: context,
          builder: (overlayContext) => _buildStandaloneDetailOverlay(
            overlayContext,
            summary,
            representativeCip,
          ),
        );
    }
  }

  // WHY: Detail overlay for standalone products (replaces StandaloneSearchResult detail)
  Widget _buildStandaloneDetailOverlay(
    BuildContext context,
    MedicamentSummaryData summary,
    String representativeCip,
  ) {
    final sanitizedPrinciples = summary.principesActifsCommuns
        .map(sanitizeActivePrinciple)
        .toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
      child: ShadCard(
        child: PharmaSheetLayout(
          title: Strings.medicationDetails,
          onClose: () => Navigator.of(context).maybePop(),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DetailItem(
                  label: Strings.nameLabel,
                  value: summary.nomCanonique,
                ),
                if (sanitizedPrinciples.isNotEmpty) ...[
                  const Gap(AppDimens.spacingMd),
                  DetailItem(
                    label: Strings.activePrinciplesLabel,
                    value: sanitizedPrinciples.join(', '),
                  ),
                ],
                const Gap(AppDimens.spacingMd),
                DetailItem(label: Strings.cip, value: representativeCip),
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
                    style: ShadTheme.of(context).textTheme.small,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
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
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
    );
  }
}
