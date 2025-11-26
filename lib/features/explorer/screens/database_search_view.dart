// lib/features/explorer/screens/database_search_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/adaptive_overlay.dart';
import 'package:pharma_scan/core/utils/app_animations.dart';
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
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_card.dart';
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
    final theme = ShadTheme.of(context);
    final searchController = useTextEditingController();
    final scrollController = useScrollController();

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

    final filters = ref.watch(searchFiltersProvider);
    final groups = ref.watch(genericGroupsProvider);
    // WHY: Watch provider with controller text directly - debouncing handled in provider
    final currentQuery = searchController.text.trim();
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
      return Scaffold(
        backgroundColor: theme.colorScheme.background,
        body: const SafeArea(
          child: StatusView(
            type: StatusType.loading,
            icon: LucideIcons.loader,
            title: Strings.initializationInProgress,
            description: Strings.initializationDescription,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
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
                          _buildStatsHeader(theme, stats),
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
                        theme,
                        ref,
                        searchController,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: Gap(AppDimens.spacingXs)),
                  if (!hasSearchText)
                    _buildGenericGroupsSliver(
                      theme,
                      groups,
                      ref,
                      key: const ValueKey('generic_groups_sliver'),
                    )
                  else if (!isSearching)
                    _buildSkeletonSliver(
                      theme,
                      key: const ValueKey('search_skeleton_sliver'),
                    )
                  else
                    searchResults.when(
                      skipLoadingOnReload: true,
                      data: (items) => _buildSearchResultsSliver(
                        theme,
                        items,
                        ref,
                        key: const ValueKey('search_results_sliver'),
                      ),
                      loading: () => _buildSkeletonSliver(
                        theme,
                        key: const ValueKey('search_loading_sliver'),
                      ),
                      error: (error, _) => _buildSearchErrorSliver(
                        theme,
                        error,
                        searchController,
                        ref,
                      ),
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
                child: _buildActiveFiltersBar(theme, filters, ref),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(ShadThemeData theme, Map<String, dynamic> stats) {
    final statsConfig = [
      (LucideIcons.star, Strings.totalPrinceps, '${stats['total_princeps']}'),
      (LucideIcons.pill, Strings.totalGenerics, '${stats['total_generiques']}'),
      (
        LucideIcons.activity,
        Strings.totalPrinciples,
        '${stats['total_principes']}',
      ),
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
            child: ShadCard(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimens.spacingSm,
                horizontal: AppDimens.spacingSm,
              ),
              backgroundColor: theme.colorScheme.card,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    child: Icon(
                      config.$1,
                      size: AppDimens.iconSm,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const Gap(AppDimens.spacingSm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.$2,
                        style: theme.textTheme.small.copyWith(
                          color: theme.colorScheme.mutedForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Gap(AppDimens.spacing2xs),
                      Text(config.$3, style: theme.textTheme.h4),
                    ],
                  ),
                ],
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
    ShadThemeData theme,
    WidgetRef ref,
    TextEditingController searchController,
  ) {
    final filters = ref.watch(searchFiltersProvider);
    return Row(
      children: [
        Expanded(child: _buildSearchBar(theme, ref, searchController)),
        const Gap(AppDimens.spacingXs),
        _buildFiltersButton(context, theme, filters, ref),
      ],
    );
  }

  Widget _buildSearchBar(
    ShadThemeData theme,
    WidgetRef ref,
    TextEditingController searchController,
  ) {
    // WHY: Watch the provider to see if it's actually fetching data
    // Debouncing is handled inside the provider, so we only show loading when actively fetching
    final currentQuery = searchController.text.trim();
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
            final theme = ShadTheme.of(context);

            final backgroundColor = theme.colorScheme.muted.withValues(
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
                  child: ShadInput(
                    controller: searchController,
                    placeholder: const Text(Strings.searchPlaceholder),
                    onChanged: (_) {
                      // WHY: Provider handles debouncing - just trigger rebuild
                      // The searchResultsProvider will debounce internally via Future.delayed
                    },
                    decoration: ShadDecoration.none,
                    leading: Icon(
                      LucideIcons.search,
                      size: AppDimens.iconSm,
                      color: theme.colorScheme.mutedForeground,
                    ),
                    trailing: isFetching
                        ? Semantics(
                            label: Strings.searchingInProgress,
                            liveRegion: true,
                            child: SizedBox(
                              width: AppDimens.iconSm,
                              height: AppDimens.iconSm,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.mutedForeground,
                                ),
                              ),
                            ),
                          )
                        : hasText
                        ? Testable(
                            id: TestTags.searchClearBtn,
                            child: Semantics(
                              button: true,
                              label: Strings.clearSearch,
                              child: ShadButton.ghost(
                                onPressed: () {
                                  searchController.clear();
                                },
                                width: AppDimens.iconLg,
                                height: AppDimens.iconLg,
                                padding: EdgeInsets.zero,
                                child: Icon(
                                  LucideIcons.x,
                                  size: AppDimens.iconSm,
                                  color: theme.colorScheme.mutedForeground,
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
    ShadThemeData theme,
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
                  onTap: () => _openFiltersSheet(context, theme, filters, ref),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.border),
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.slidersHorizontal,
                      size: 18,
                      color: theme.colorScheme.foreground,
                    ),
                  ),
                ),
                if (hasActiveFilters)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Semantics(
                      label: Strings.activeFilterCount(filterCount),
                      child: ShadBadge(
                        backgroundColor: theme.colorScheme.primary,
                        child: Text(
                          '$filterCount',
                          style: theme.textTheme.small.copyWith(
                            color: theme.colorScheme.primaryForeground,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
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
    ShadThemeData theme,
    SearchFilters currentFilters,
    WidgetRef ref,
  ) {
    return showAdaptiveOverlay(
      context: context,
      builder: (overlayContext) =>
          _buildFiltersPanel(overlayContext, theme, currentFilters, ref),
    );
  }

  Widget _buildActiveFiltersBar(
    ShadThemeData theme,
    SearchFilters filters,
    WidgetRef ref,
  ) {
    final chips = <Widget>[];
    if (filters.voieAdministration != null) {
      chips.add(
        ShadBadge(
          child: Text(
            filters.voieAdministration!,
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.primaryForeground,
            ),
          ),
        ),
      );
    }
    if (filters.atcClass != null) {
      final atcLabel =
          Strings.getAtcLevel1Label(filters.atcClass) ?? filters.atcClass!;
      chips.add(
        ShadBadge(
          child: Text(
            atcLabel,
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.primaryForeground,
            ),
          ),
        ),
      );
    }

    final hasChips = chips.isNotEmpty;

    return ShadCard(
      padding: const EdgeInsets.all(AppDimens.spacingMd),
      child: Row(
        children: [
          Expanded(
            child: hasChips
                ? Wrap(spacing: 8, runSpacing: 8, children: chips)
                : Text(Strings.noActiveFilters, style: theme.textTheme.muted),
          ),
          const Gap(AppDimens.spacingSm),
          Semantics(
            button: true,
            label: Strings.resetAllFilters,
            enabled: hasChips,
            child: ShadButton.ghost(
              onPressed: hasChips
                  ? ref.read(searchFiltersProvider.notifier).clearFilters
                  : null,
              child: const Text(Strings.resetFilters),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel(
    BuildContext context,
    ShadThemeData theme,
    SearchFilters currentFilters,
    WidgetRef ref,
  ) {
    return ShadCard(
      padding: const EdgeInsets.all(AppDimens.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(Strings.filters, style: theme.textTheme.h4),
              ShadButton.ghost(
                onPressed: currentFilters.hasActiveFilters
                    ? ref.read(searchFiltersProvider.notifier).clearFilters
                    : null,
                padding: EdgeInsets.zero,
                child: Text(
                  Strings.resetFilters,
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const Gap(AppDimens.spacingMd),
          Text(
            Strings.administrationRouteFilter,
            style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(AppDimens.spacingXs),
          _buildPharmaceuticalFormFilter(context, theme, currentFilters, ref),
          const Gap(AppDimens.spacingMd),
          Text(
            Strings.therapeuticClassFilter,
            style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(AppDimens.spacingXs),
          _buildTherapeuticClassFilter(context, theme, currentFilters, ref),
        ],
      ),
    );
  }

  Widget _buildPharmaceuticalFormFilter(
    BuildContext context,
    ShadThemeData theme,
    SearchFilters currentFilters,
    WidgetRef ref,
  ) {
    final routesAsync = ref.watch(administrationRoutesProvider);

    return routesAsync.when(
      data: (routes) {
        if (routes.isEmpty) {
          return Text(Strings.noRoutesAvailable, style: theme.textTheme.muted);
        }

        return ShadSelect<String?>(
          minWidth: double.infinity,
          placeholder: const Text(Strings.allRoutes),
          initialValue: currentFilters.voieAdministration,
          options: [
            const ShadOption<String?>(
              value: null,
              child: Text(Strings.allRoutes),
            ),
            ...routes.map(
              (route) => ShadOption<String?>(value: route, child: Text(route)),
            ),
          ],
          selectedOptionBuilder: (context, value) {
            if (value == null) {
              return const Text(Strings.allRoutes);
            }
            return Text(value);
          },
          onChanged: (value) {
            ref
                .read(searchFiltersProvider.notifier)
                .updateFilters(
                  currentFilters.copyWith(voieAdministration: value),
                );
            Navigator.of(context).maybePop();
          },
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
                theme.colorScheme.mutedForeground,
              ),
            ),
          ),
        ),
      ),
      error: (error, stackTrace) =>
          Text(Strings.errorLoadingRoutes, style: theme.textTheme.muted),
    );
  }

  Widget _buildTherapeuticClassFilter(
    BuildContext context,
    ShadThemeData theme,
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

    return ShadSelect<String?>(
      minWidth: double.infinity,
      placeholder: const Text(Strings.allClasses),
      initialValue: currentFilters.atcClass,
      options: [
        const ShadOption<String?>(value: null, child: Text(Strings.allClasses)),
        ...atcOptions.map(
          (option) =>
              ShadOption<String?>(value: option.$1, child: Text(option.$2)),
        ),
      ],
      selectedOptionBuilder: (context, value) {
        if (value == null) {
          return const Text(Strings.allClasses);
        }
        final label = atcOptions
            .firstWhere(
              (option) => option.$1 == value,
              orElse: () => (value, value),
            )
            .$2;
        return Text(label);
      },
      onChanged: (value) {
        ref
            .read(searchFiltersProvider.notifier)
            .updateFilters(currentFilters.copyWith(atcClass: value));
        Navigator.of(context).maybePop();
      },
    );
  }

  Widget _buildGroupsError(ShadThemeData theme, WidgetRef ref) {
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

  // Sliver versions for CustomScrollView
  Widget _buildGenericGroupsSliver(
    ShadThemeData theme,
    AsyncValue<GenericGroupsState> groups,
    WidgetRef ref, {
    Key? key,
  }) {
    Widget sliver;
    if (groups.isLoading) {
      sliver = _buildSkeletonSliver(theme);
    } else {
      final data = groups.asData?.value;
      if (groups.hasError && (data == null || data.items.isEmpty)) {
        sliver = SliverToBoxAdapter(child: _buildGroupsError(theme, ref));
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
                    child: const ShadProgress(),
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
                  onTap: () =>
                      context.push(AppRoutes.groupDetail(group.groupId)),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  highlightColor: theme.colorScheme.primary.withValues(
                    alpha: 0.05,
                  ),
                  child: ShadCard(
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
                                style: theme.textTheme.small.copyWith(
                                  color: theme.colorScheme.mutedForeground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Gap(AppDimens.spacingXs),
                              Text(
                                group.princepsReferenceName,
                                style: theme.textTheme.p.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
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
                            LucideIcons.arrowRightLeft,
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Strings.activePrinciplesLabel,
                                style: theme.textTheme.small.copyWith(
                                  color: theme.colorScheme.mutedForeground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Gap(AppDimens.spacingXs),
                              Text(
                                group.commonPrincipes.isEmpty
                                    ? Strings.notDetermined
                                    : group.commonPrincipes,
                                style: theme.textTheme.p,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ),
                        const Gap(AppDimens.spacingXs),
                        Icon(
                          LucideIcons.chevronRight,
                          size: AppDimens.iconSm,
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ],
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

  Widget _buildSkeletonSliver(ShadThemeData theme, {Key? key}) {
    final placeholderColor = theme.colorScheme.muted.withValues(alpha: 0.3);
    final sliver = SliverList.separated(
      itemCount: 4,
      separatorBuilder: (context, index) => const Gap(AppDimens.spacingSm),
      itemBuilder: (context, index) {
        return ShadCard(
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
        );
      },
    );
    return _wrapSliverWithKey(sliver, key);
  }

  Widget _buildSearchResultsSliver(
    ShadThemeData theme,
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
                Text(Strings.noResults, style: theme.textTheme.muted),
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
        ),
        key,
      );
    }

    final sliver = SliverList.separated(
      itemCount: results.length,
      separatorBuilder: (context, index) => const Gap(AppDimens.spacingSm),
      itemBuilder: (context, index) {
        final result = results[index];
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
          child: result.when(
            groupResult: (group) => Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push(AppRoutes.groupDetail(group.groupId)),
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                highlightColor: theme.colorScheme.primary.withValues(
                  alpha: 0.05,
                ),
                child: GroupResultCard(group: group),
              ),
            ),
            princepsResult: (princeps, generics, groupId, unusedPrinciples) =>
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push(AppRoutes.groupDetail(groupId)),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    splashColor: theme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    highlightColor: theme.colorScheme.primary.withValues(
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
                    onTap: () => context.push(AppRoutes.groupDetail(groupId)),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    splashColor: theme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    highlightColor: theme.colorScheme.primary.withValues(
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
                  final theme = ShadTheme.of(context);
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
                      ShadBadge(
                        backgroundColor: theme.colorScheme.muted,
                        child: Text(
                          Strings.uniqueMedicationBadge,
                          style: theme.textTheme.small.copyWith(
                            color: theme.colorScheme.mutedForeground,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      size: AppDimens.iconSm,
                      color: theme.colorScheme.mutedForeground,
                    ),
                    onTap: () {
                      showAdaptiveOverlay(
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
          ),
        ).animate(delay: (index * 40).ms, effects: AppAnimations.listItemEnter);
      },
    );
    return _wrapSliverWithKey(sliver, key);
  }

  Widget _buildSearchErrorSliver(
    ShadThemeData theme,
    Object error,
    TextEditingController searchController,
    WidgetRef ref,
  ) {
    // WHY: Use current query from controller instead of _activeQuery state
    final currentQuery = searchController.text.trim();
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
    final theme = ShadTheme.of(context);
    final sanitizedPrinciples = summary.principesActifsCommuns
        .map(sanitizeActivePrinciple)
        .toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
      child: ShadCard(
        padding: EdgeInsets.zero,
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
                ShadBadge.outline(
                  child: Text(
                    Strings.uniqueMedicationNoGroup,
                    style: theme.textTheme.small,
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
    final theme = ShadTheme.of(context);
    return Container(
      height: height,
      color: theme.colorScheme.background,
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
