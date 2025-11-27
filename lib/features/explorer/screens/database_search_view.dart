// lib/features/explorer/screens/database_search_view.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/router/routes.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/adaptive_overlay.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/testable.dart';
import 'package:pharma_scan/features/explorer/widgets/search_results/generic_result_card.dart';
import 'package:pharma_scan/features/explorer/widgets/search_results/group_result_card.dart';
import 'package:pharma_scan/features/explorer/widgets/search_results/princeps_result_card.dart';
import 'package:pharma_scan/core/widgets/ui_kit/detail_item.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_sheet_layout.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/features/explorer/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/models/search_result_item_model.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_card.dart';
import 'package:forui/forui.dart';
import 'package:pharma_scan/features/explorer/providers/database_stats_provider.dart';
import 'package:pharma_scan/features/explorer/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/providers/pharmaceutical_forms_provider.dart';
import 'package:pharma_scan/features/explorer/providers/search_provider.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';

class DatabaseSearchView extends HookConsumerWidget {
  const DatabaseSearchView({super.key});

  static const double _searchHeaderHeight = 68;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final scrollController = useScrollController();
    final debouncedQuery = useState('');
    final debounceTimer = useRef<Timer?>(null);

    // WHY: Set up scroll listener for pagination using useEffect
    useEffect(() {
      void onScroll() {
        if (!scrollController.hasClients) return;
        // WHY: Don't trigger group pagination when user is searching
        // Search results are capped at 50 by FuzzyBolt, so pagination isn't needed
        if (searchController.text.trim().isNotEmpty) {
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

    // WHY: Debounce search input so database queries are not fired on every keystroke.
    // debouncedQuery is the single source of truth for searchResultsProvider.
    useEffect(() {
      void listener() {
        debounceTimer.value?.cancel();
        debounceTimer.value = Timer(const Duration(milliseconds: 300), () {
          debouncedQuery.value = searchController.text.trim();
        });
      }

      searchController.addListener(listener);
      return () {
        debounceTimer.value?.cancel();
        searchController.removeListener(listener);
      };
    }, [searchController]);

    final filters = ref.watch(searchFiltersProvider);
    final groups = ref.watch(genericGroupsProvider);
    // WHY: Watch provider with debounced query to avoid rebuilds on every keystroke
    final currentQuery = debouncedQuery.value;
    final searchResults = ref.watch(searchResultsProvider(currentQuery));
    final databaseStats = ref.watch(databaseStatsProvider);
    final hasSearchText = currentQuery.isNotEmpty;
    final isSearching = hasSearchText;
    final showFiltersBar = filters.hasActiveFilters;
    final initStepAsync = ref.watch(initializationStepProvider);

    // WHY: Show initialization placeholder if database is not ready
    // This prevents showing "No results" during initialization
    // Exclude error state so MainScreen error banner is visible
    final initStep = initStepAsync.value;
    if (initStep != null &&
        initStep != InitializationStep.ready &&
        initStep != InitializationStep.error) {
      return const FScaffold(
        child: SafeArea(
          child: StatusView(
            type: StatusType.loading,
            icon: FIcons.loader,
            title: Strings.initializationInProgress,
            description: Strings.initializationDescription,
          ),
        ),
      );
    }

    return FScaffold(
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingMd,
              ),
              child: CustomScrollView(
                controller: scrollController,
                slivers: [
                  databaseStats.when(
                    data: (stats) => SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildStatsHeader(context, stats),
                          const Gap(AppDimens.spacingMd),
                        ],
                      ),
                    ),
                    loading: () =>
                        const SliverToBoxAdapter(child: SizedBox.shrink()),
                    error: (_, _) =>
                        const SliverToBoxAdapter(child: SizedBox.shrink()),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SearchBarHeaderDelegate(
                      height: _searchHeaderHeight,
                      child: _buildSearchBarWithFilters(
                        context,
                        ref,
                        searchController,
                        debouncedQuery,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: Gap(AppDimens.spacingXs)),
                  if (!hasSearchText)
                    _buildGenericGroupsSliver(
                      groups,
                      ref,
                      key: const ValueKey('generic_groups_sliver'),
                    )
                  else if (!isSearching)
                    _buildSkeletonSliver(
                      key: const ValueKey('search_skeleton_sliver'),
                    )
                  else
                    searchResults.when(
                      skipLoadingOnReload: true,
                      data: (items) => _buildSearchResultsSliver(
                        context,
                        items,
                        ref,
                        key: const ValueKey('search_results_sliver'),
                      ),
                      loading: () => _buildSkeletonSliver(
                        key: const ValueKey('search_loading_sliver'),
                      ),
                      error: (error, _) =>
                          _buildSearchErrorSliver(error, currentQuery, ref),
                    ),
                  // Espaceur pour scroller au-dessus de la barre de filtre
                  SliverToBoxAdapter(
                    child: SizedBox(height: showFiltersBar ? 100 : 20),
                  ),
                ],
              ),
            ),
            if (showFiltersBar)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _buildActiveFiltersBar(filters, ref),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(BuildContext context, Map<String, dynamic> stats) {
    final statsConfig = [
      (FIcons.star, Strings.totalPrinceps, '${stats['total_princeps']}'),
      (FIcons.pill, Strings.totalGenerics, '${stats['total_generiques']}'),
      (FIcons.activity, Strings.totalPrinciples, '${stats['total_principes']}'),
    ];

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(
          top: AppDimens.spacingMd,
          right: AppDimens.spacingSm,
        ),
        itemBuilder: (context, index) {
          final config = statsConfig[index];
          return ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 140),
            child: FCard.raw(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimens.spacingSm,
                  horizontal: AppDimens.spacingSm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.theme.colors.primary.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                      ),
                      child: Icon(
                        config.$1,
                        size: AppDimens.iconSm,
                        color: context.theme.colors.primary,
                      ),
                    ),
                    const Gap(AppDimens.spacingSm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.$2,
                          style: context.theme.typography.sm.copyWith(
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                        const Gap(AppDimens.spacing2xs),
                        Text(
                          config.$3,
                          style: context.theme.typography.xl2, // h4 equivalent
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, index) => const Gap(AppDimens.spacingSm),
        itemCount: statsConfig.length,
      ),
    );
  }

  Widget _buildSearchBarWithFilters(
    BuildContext context,
    WidgetRef ref,
    TextEditingController searchController,
    ValueNotifier<String> debouncedQuery,
  ) {
    final filters = ref.watch(searchFiltersProvider);
    return Row(
      children: [
        Expanded(
          child: _buildSearchBar(
            context,
            ref,
            searchController,
            debouncedQuery,
          ),
        ),
        const Gap(AppDimens.spacingXs),
        _buildFiltersButton(context, filters, ref),
      ],
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    WidgetRef ref,
    TextEditingController searchController,
    ValueNotifier<String> debouncedQuery,
  ) {
    // WHY: Watch the provider to see if it's actually fetching data
    // Debouncing is handled via debouncedQuery, so we only show loading when actively fetching
    final currentQuery = debouncedQuery.value;
    final isFetching = ref.watch(searchResultsProvider(currentQuery)).isLoading;
    return Testable(
      id: TestTags.searchInput,
      child: Semantics(
        textField: true,
        label: Strings.searchLabel,
        hint: Strings.searchHint,
        value: searchController.text,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: searchController,
          builder: (context, value, _) {
            final hasText = value.text.isNotEmpty;
            final backgroundColor = context.theme.colors.muted.withValues(
              alpha: 0.08,
            );
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spacingSm,
                  ),
                  child: FTextField(
                    controller: searchController,
                    hint: Strings.searchPlaceholder,
                    onChange: (_) {
                      // WHY: Provider handles debouncing - just trigger rebuild
                      // The searchResultsProvider will debounce internally via Future.delayed
                    },
                    prefixBuilder: (context, style, states) => Icon(
                      FIcons.search,
                      size: AppDimens.iconSm,
                      color: context.theme.colors.mutedForeground,
                    ),
                    suffixBuilder: isFetching
                        ? (context, style, states) => Semantics(
                            label: Strings.searchingInProgress,
                            liveRegion: true,
                            child: SizedBox(
                              width: AppDimens.iconSm,
                              height: AppDimens.iconSm,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  context.theme.colors.mutedForeground,
                                ),
                              ),
                            ),
                          )
                        : hasText
                        ? (context, style, states) => Testable(
                            id: TestTags.searchClearBtn,
                            child: Semantics(
                              button: true,
                              label: Strings.clearSearch,
                              child: FButton.icon(
                                style: FButtonStyle.ghost(),
                                onPress: () {
                                  searchController.clear();
                                },
                                child: const Icon(
                                  FIcons.x,
                                  size: AppDimens.iconLg,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFiltersButton(
    BuildContext context,
    SearchFilters filters,
    WidgetRef ref,
  ) {
    final hasActiveFilters = filters.hasActiveFilters;
    final filterCount =
        (filters.voieAdministration != null ? 1 : 0) +
        (filters.atcClass != null ? 1 : 0);
    final filterLabel = hasActiveFilters
        ? Strings.editFilters
        : Strings.openFilters;
    final filterValue = hasActiveFilters
        ? Strings.activeFilterCount(filterCount)
        : null;

    return Testable(
      id: TestTags.filterBtn,
      child: Semantics(
        button: true,
        label: filterLabel,
        value: filterValue,
        hint: Strings.filterHint,
        child: SizedBox(
          width: 56,
          height: 48,
          child: Material(
            color: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm),
            child: Stack(
              alignment: Alignment.center,
              children: [
                InkWell(
                  onTap: () => _openFiltersSheet(context, filters, ref),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: context.theme.colors.border),
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      FIcons.slidersHorizontal,
                      size: 18,
                      color: context.theme.colors.foreground,
                    ),
                  ),
                ),
                if (hasActiveFilters)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Semantics(
                      label: Strings.activeFilterCount(filterCount),
                      child: FBadge(
                        style: FBadgeStyle.primary(),
                        child: Text(
                          '$filterCount',
                          style: context.theme.typography.sm,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFiltersSheet(
    BuildContext context,
    SearchFilters currentFilters,
    WidgetRef ref,
  ) {
    return showAdaptiveOverlay(
      context: context,
      builder: (overlayContext) =>
          _buildFiltersPanel(overlayContext, currentFilters, ref),
    );
  }

  Widget _buildActiveFiltersBar(SearchFilters filters, WidgetRef ref) {
    return Builder(
      builder: (context) {
        final chips = <Widget>[];
        if (filters.voieAdministration != null) {
          chips.add(
            FBadge(
              style: FBadgeStyle.primary(),
              child: Text(
                filters.voieAdministration!,
                style: context.theme.typography.sm,
              ),
            ),
          );
        }
        if (filters.atcClass != null) {
          final atcLabel =
              Strings.getAtcLevel1Label(filters.atcClass) ?? filters.atcClass!;
          chips.add(
            FBadge(
              style: FBadgeStyle.primary(),
              child: Text(atcLabel, style: context.theme.typography.sm),
            ),
          );
        }

        final hasChips = chips.isNotEmpty;

        return FCard.raw(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spacingMd),
            child: Row(
              children: [
                Expanded(
                  child: hasChips
                      ? Wrap(spacing: 8, runSpacing: 8, children: chips)
                      : Text(
                          Strings.noActiveFilters,
                          style: context.theme.typography.sm.copyWith(
                            color: context.theme.colors.mutedForeground,
                          ),
                        ),
                ),
                const Gap(AppDimens.spacingSm),
                Semantics(
                  button: true,
                  label: Strings.resetAllFilters,
                  enabled: hasChips,
                  child: FButton(
                    style: FButtonStyle.ghost(),
                    onPress: hasChips
                        ? ref.read(searchFiltersProvider.notifier).clearFilters
                        : null,
                    child: const Text(Strings.resetFilters),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFiltersPanel(
    BuildContext context,
    SearchFilters currentFilters,
    WidgetRef ref,
  ) {
    return FCard.raw(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Strings.filters,
                  style: context.theme.typography.xl2, // h4 equivalent
                ),
                FButton(
                  style: FButtonStyle.ghost(),
                  onPress: currentFilters.hasActiveFilters
                      ? ref.read(searchFiltersProvider.notifier).clearFilters
                      : null,
                  child: const Text(Strings.resetFilters),
                ),
              ],
            ),
            const Gap(AppDimens.spacingMd),
            Text(
              Strings.administrationRouteFilter,
              style: context.theme.typography.sm,
            ),
            const Gap(AppDimens.spacingXs),
            _buildPharmaceuticalFormFilter(context, currentFilters, ref),
            const Gap(AppDimens.spacingMd),
            Text(
              Strings.therapeuticClassFilter,
              style: context.theme.typography.sm,
            ),
            const Gap(AppDimens.spacingXs),
            _buildTherapeuticClassFilter(context, currentFilters, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildPharmaceuticalFormFilter(
    BuildContext context,
    SearchFilters currentFilters,
    WidgetRef ref,
  ) {
    final routesAsync = ref.watch(administrationRoutesProvider);

    return routesAsync.when(
      data: (routes) {
        if (routes.isEmpty) {
          return Text(
            Strings.noRoutesAvailable,
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          );
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(minWidth: double.infinity),
          child: FSelect<String?>.rich(
            hint: Strings.allRoutes,
            format: (value) => value ?? Strings.allRoutes,
            initialValue: currentFilters.voieAdministration,
            onChange: (value) {
              ref
                  .read(searchFiltersProvider.notifier)
                  .updateFilters(
                    currentFilters.copyWith(voieAdministration: value),
                  );
              Navigator.of(context).maybePop();
            },
            children: [
              FSelectItem<String?>(
                title: Text(
                  Strings.allRoutes,
                  style: context.theme.typography.base,
                ),
                value: null,
              ),
              ...routes.map(
                (route) => FSelectItem<String?>(
                  title: Text(route, style: context.theme.typography.base),
                  value: route,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => SizedBox(
        height: 40,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                context.theme.colors.mutedForeground,
              ),
            ),
          ),
        ),
      ),
      error: (error, stackTrace) => Text(
        Strings.errorLoadingRoutes,
        style: context.theme.typography.sm.copyWith(
          color: context.theme.colors.mutedForeground,
        ),
      ),
    );
  }

  Widget _buildTherapeuticClassFilter(
    BuildContext context,
    SearchFilters currentFilters,
    WidgetRef ref,
  ) {
    // ATC Level 1 codes and their labels
    const atcOptions = [
      ('A', 'Système digestif'),
      ('B', 'Sang'),
      ('C', 'Système cardio-vasculaire'),
      ('D', 'Dermatologie'),
      ('G', 'Système génito-urinaire'),
      ('H', 'Hormones'),
      ('J', 'Anti-infectieux'),
      ('L', 'Antinéoplasiques'),
      ('M', 'Muscles et Squelette'),
      ('N', 'Système nerveux'),
      ('P', 'Antiparasitaires'),
      ('R', 'Système respiratoire'),
      ('S', 'Organes sensoriels'),
      ('V', 'Divers'),
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: double.infinity),
      child: FSelect<String?>.rich(
        hint: Strings.allClasses,
        format: (value) => value ?? Strings.allClasses,
        initialValue: currentFilters.atcClass,
        onChange: (value) {
          ref
              .read(searchFiltersProvider.notifier)
              .updateFilters(currentFilters.copyWith(atcClass: value));
          Navigator.of(context).maybePop();
        },
        children: [
          FSelectItem<String?>(
            title: Text(
              Strings.allClasses,
              style: context.theme.typography.base,
            ),
            value: null,
          ),
          ...atcOptions.map(
            (option) => FSelectItem<String?>(
              title: Text(option.$2, style: context.theme.typography.base),
              value: option.$1,
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
        child: FButton(
          style: FButtonStyle.primary(),
          onPress: () => ref.invalidate(genericGroupsProvider),
          child: const Text(Strings.retry),
        ),
      ),
    );
  }

  // Sliver versions for CustomScrollView
  Widget _buildGenericGroupsSliver(
    AsyncValue<GenericGroupsState> groups,
    WidgetRef ref, {
    Key? key,
  }) {
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
        sliver = SliverList.separated(
          itemCount: data.items.length + (data.isLoadingMore ? 1 : 0),
          separatorBuilder: (context, index) {
            if (index == data.items.length) {
              return const SizedBox.shrink();
            }
            return const Gap(AppDimens.spacingSm);
          },
          itemBuilder: (context, index) {
            if (index == data.items.length) {
              return Padding(
                padding: const EdgeInsets.all(AppDimens.spacingMd),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.theme.colors.primary,
                      ),
                    ),
                  ),
                ),
              );
            }
            final group = data.items[index];
            return Semantics(
              button: true,
              label:
                  'Groupe ${group.groupId}, princeps ${group.princepsReferenceName}, principes actifs ${group.commonPrincipes.isEmpty ? "non déterminé" : group.commonPrincipes}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => GroupDetailRoute(
                    groupId: group.groupId,
                  ).push<void>(context),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  splashColor: context.theme.colors.primary.withValues(
                    alpha: 0.1,
                  ),
                  highlightColor: context.theme.colors.primary.withValues(
                    alpha: 0.05,
                  ),
                  child: FCard.raw(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.spacingLg),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Strings.princepsLabel,
                                  style: context.theme.typography.sm.copyWith(
                                    color: context.theme.colors.mutedForeground,
                                  ),
                                ),
                                const Gap(AppDimens.spacingXs),
                                Text(
                                  group.princepsReferenceName,
                                  style: context.theme.typography.base,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimens.spacingMd,
                            ),
                            child: Icon(
                              FIcons.arrowRightLeft,
                              color: context.theme.colors.mutedForeground,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  Strings.activePrinciplesLabel,
                                  style: context.theme.typography.sm.copyWith(
                                    color: context.theme.colors.mutedForeground,
                                  ),
                                ),
                                const Gap(AppDimens.spacingXs),
                                Text(
                                  group.commonPrincipes.isEmpty
                                      ? Strings.notDetermined
                                      : group.commonPrincipes,
                                  style: context.theme.typography.base,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                          const Gap(AppDimens.spacingXs),
                          Icon(
                            FIcons.chevronRight,
                            size: AppDimens.iconSm,
                            color: context.theme.colors.mutedForeground,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }
    }
    return _wrapSliverWithKey(sliver, key);
  }

  Widget _buildSkeletonSliver({Key? key}) {
    // Note: This method needs context for token resolution, but we'll resolve it in the builder
    final sliver = Builder(
      builder: (context) {
        final placeholderColor = context.theme.colors.muted.withValues(
          alpha: 0.3,
        );
        return SliverList.separated(
          itemCount: 4,
          separatorBuilder: (context, index) => const Gap(AppDimens.spacingSm),
          itemBuilder: (context, index) {
            return FCard.raw(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.spacingLg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonBlock(height: 14, color: placeholderColor),
                          const Gap(AppDimens.spacingXs),
                          _SkeletonBlock(height: 16, color: placeholderColor),
                          const Gap(AppDimens.spacingXs),
                          _SkeletonBlock(
                            height: 16,
                            width: 120,
                            color: placeholderColor,
                          ),
                        ],
                      ),
                    ),
                    const Gap(AppDimens.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonBlock(height: 14, color: placeholderColor),
                          const Gap(AppDimens.spacingXs),
                          _SkeletonBlock(height: 16, color: placeholderColor),
                        ],
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
    return _wrapSliverWithKey(sliver, key);
  }

  Widget _buildSearchResultsSliver(
    BuildContext context,
    List<SearchResultItem> results,
    WidgetRef ref, {
    Key? key,
  }) {
    if (results.isEmpty) {
      final filters = ref.watch(searchFiltersProvider);
      final hasFilters = filters.hasActiveFilters;
      return _wrapSliverWithKey(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spacing2xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  Strings.noResults,
                  style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
                if (hasFilters) ...[
                  const Gap(AppDimens.spacingSm),
                  Semantics(
                    button: true,
                    label: Strings.resetAllFilters,
                    child: FButton(
                      style: FButtonStyle.outline(),
                      onPress: ref
                          .read(searchFiltersProvider.notifier)
                          .clearFilters,
                      child: const Text(Strings.clearFilters),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        key,
      );
    }

    final sliver = SliverList.separated(
      itemCount: results.length,
      separatorBuilder: (context, index) => const Gap(AppDimens.spacingSm),
      itemBuilder: (context, index) {
        final result = results[index];
        final child = result.when(
          groupResult: (group) => Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  GroupDetailRoute(groupId: group.groupId).push<void>(context),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              splashColor: context.theme.colors.primary.withValues(alpha: 0.1),
              highlightColor: context.theme.colors.primary.withValues(
                alpha: 0.05,
              ),
              child: GroupResultCard(group: group),
            ),
          ),
          princepsResult: (princeps, generics, groupId, unusedPrinciples) =>
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      GroupDetailRoute(groupId: groupId).push<void>(context),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  splashColor: context.theme.colors.primary.withValues(
                    alpha: 0.1,
                  ),
                  highlightColor: context.theme.colors.primary.withValues(
                    alpha: 0.05,
                  ),
                  child: PrincepsResultCard(
                    princeps: princeps,
                    generics: generics,
                  ),
                ),
              ),
          genericResult: (generic, princepsList, groupId, unusedPrinciples) =>
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      GroupDetailRoute(groupId: groupId).push<void>(context),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  splashColor: context.theme.colors.primary.withValues(
                    alpha: 0.1,
                  ),
                  highlightColor: context.theme.colors.primary.withValues(
                    alpha: 0.05,
                  ),
                  child: GenericResultCard(
                    generic: generic,
                    princeps: princepsList,
                  ),
                ),
              ),
          standaloneResult:
              (cisCode, summary, representativeCip, unusedPrinciples) {
                final sanitizedPrinciples = summary.principesActifsCommuns
                    .map(sanitizeActivePrinciple)
                    .toList();
                final description =
                    summary.formePharmaceutique != null &&
                        sanitizedPrinciples.isNotEmpty
                    ? '${summary.formePharmaceutique} - ${sanitizedPrinciples.join(' + ')}'
                    : summary.formePharmaceutique ??
                          (sanitizedPrinciples.isNotEmpty
                              ? sanitizedPrinciples.join(' + ')
                              : null);

                return ProductCard(
                  summary: summary,
                  cip: representativeCip,
                  groupLabel: summary.groupId != null
                      ? summary.princepsBrandName
                      : null,
                  subtitle: description != null ? [description] : null,
                  badges: [
                    FBadge(
                      style: FBadgeStyle.primary(),
                      child: Text(
                        Strings.uniqueMedicationBadge,
                        style: context.theme.typography.sm,
                      ),
                    ),
                  ],
                  trailing: Icon(
                    FIcons.chevronRight,
                    size: AppDimens.iconSm,
                    color: context.theme.colors.mutedForeground,
                  ),
                  onTap: () {
                    showAdaptiveOverlay<void>(
                      context: context,
                      builder: (overlayContext) =>
                          _buildStandaloneDetailOverlay(
                            overlayContext,
                            summary,
                            representativeCip,
                          ),
                    );
                  },
                );
              },
        );
        return Semantics(
          button: true,
          label: result.when(
            groupResult: (group) =>
                'Groupe ${group.groupId}, princeps ${group.princepsReferenceName}, principes actifs ${group.commonPrincipes.isEmpty ? "non déterminé" : group.commonPrincipes}',
            princepsResult: (princeps, generics, groupId, unusedPrinciples) =>
                Strings.searchResultSemanticsForPrinceps(
                  princeps.nomCanonique,
                  generics.length,
                ),
            genericResult: (generic, princepsList, groupId, unusedPrinciples) =>
                Strings.searchResultSemanticsForGeneric(
                  generic.nomCanonique,
                  princepsList.length,
                ),
            standaloneResult:
                (cisCode, summary, representativeCip, unusedPrinciples) =>
                    '${Strings.medication} ${summary.nomCanonique}',
          ),
          child: child,
        );
      },
    );
    return _wrapSliverWithKey(sliver, key);
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
        action: FButton(
          style: FButtonStyle.primary(),
          onPress: () => ref.invalidate(searchResultsProvider(currentQuery)),
          child: const Text(Strings.retry),
        ),
      ),
    );
  }

  Widget _wrapSliverWithKey(Widget sliver, Key? key) {
    if (key == null) return sliver;
    return SliverPadding(key: key, padding: EdgeInsets.zero, sliver: sliver);
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
      child: FCard.raw(
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
                  const Gap(16),
                  DetailItem(
                    label: Strings.activePrinciplesLabel,
                    value: sanitizedPrinciples.join(', '),
                  ),
                ],
                const Gap(16),
                DetailItem(label: Strings.cip, value: representativeCip),
                if (summary.titulaire != null &&
                    summary.titulaire!.isNotEmpty) ...[
                  const Gap(16),
                  DetailItem(label: Strings.holder, value: summary.titulaire!),
                ],
                if (summary.formePharmaceutique != null &&
                    summary.formePharmaceutique!.isNotEmpty) ...[
                  const Gap(16),
                  DetailItem(
                    label: Strings.pharmaceuticalFormLabel,
                    value: summary.formePharmaceutique!,
                  ),
                ],
                const Gap(16),
                FBadge(
                  style: FBadgeStyle.outline(),
                  child: Text(
                    Strings.uniqueMedicationNoGroup,
                    style: context.theme.typography.sm,
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

class _SearchBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SearchBarHeaderDelegate({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: height,
      color: context.theme.colors.background,
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_SearchBarHeaderDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
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
