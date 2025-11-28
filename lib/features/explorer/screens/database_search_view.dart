// lib/features/explorer/screens/database_search_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/router/routes.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/adaptive_overlay.dart';
import 'package:pharma_scan/core/logic/sanitizer.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/testable.dart';
import 'package:pharma_scan/features/explorer/widgets/filters/administration_route_filter_tile.dart';
import 'package:pharma_scan/core/widgets/ui_kit/detail_item.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_sheet_layout.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/features/explorer/models/explorer_enums.dart';
import 'package:pharma_scan/features/explorer/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/models/search_result_item_model.dart';
import 'package:forui/forui.dart';
import 'package:pharma_scan/features/explorer/providers/database_stats_provider.dart';
import 'package:pharma_scan/features/explorer/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/providers/search_provider.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/theme/card_style.dart';
import 'package:pharma_scan/theme/badge_styles.dart';

class DatabaseSearchView extends HookConsumerWidget {
  const DatabaseSearchView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final scrollController = useScrollController();
    final searchFocusNode = useFocusNode();
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
      childPad: false, // Disable default pagePadding to remove lateral padding
      resizeToAvoidBottomInset:
          false, // Prevent automatic resizing; we manually offset the sticky bar
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
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
                  loading: () =>
                      const SliverToBoxAdapter(child: SizedBox.shrink()),
                  error: (_, _) =>
                      const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),
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
              ],
            ),
          ),
          _buildSearchFooter(
            context,
            ref,
            searchController,
            debouncedQuery,
            ValueNotifier(debounceTimer.value),
            searchFocusNode,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(BuildContext context, Map<String, dynamic> stats) {
    final statsConfig = [
      (FIcons.star, Strings.totalPrinceps, '${stats['total_princeps']}'),
      (FIcons.pill, Strings.totalGenerics, '${stats['total_generiques']}'),
      (FIcons.activity, Strings.totalPrinciples, '${stats['total_principes']}'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 360;
        final iconSize = isSmallScreen ? AppDimens.iconSm : AppDimens.iconMd;
        final valueTextStyle = isSmallScreen
            ? context.theme.typography.xl
            : context.theme.typography.xl2;
        final labelTextStyle = isSmallScreen
            ? context.theme.typography.xs
            : context.theme.typography.sm;

        return FCard.raw(
          style: context.theme.cardStyles.borderless.call,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: context.theme.colors.primary),
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
              color: context.theme.colors.mutedForeground,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildGroupSection(
    BuildContext context, {
    required Widget badge,
    required String label,
    String? name,
    required String principles,
    bool isMuted = false,
    bool showPrinciples = false,
    bool principlesAsMain = false,
  }) {
    final theme = context.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Badge + Label row
        Row(
          children: [
            badge,
            const Gap(AppDimens.spacing2xs),
            Expanded(
              child: Text(
                label,
                style: theme.typography.xs.copyWith(
                  color: theme.colors.mutedForeground,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const Gap(AppDimens.spacing2xs),
        // Medication name or principles (as main content)
        if (principlesAsMain && principles.isNotEmpty)
          Text(
            principles,
            style: theme.typography.base.copyWith(
              fontWeight: FontWeight.w600,
              color: isMuted
                  ? theme.colors.mutedForeground
                  : theme.colors.foreground,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          )
        else if (name != null)
          Text(
            name,
            style: theme.typography.base.copyWith(
              fontWeight: FontWeight.w600,
              color: isMuted
                  ? theme.colors.mutedForeground
                  : theme.colors.foreground,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        // Principles (molécule) - only shown if not as main and showPrinciples is true
        if (!principlesAsMain && showPrinciples && principles.isNotEmpty) ...[
          const Gap(AppDimens.spacing2xs),
          Text(
            principles,
            style: theme.typography.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildSearchBarWithFilters(
    BuildContext context,
    WidgetRef ref,
    TextEditingController searchController,
    ValueNotifier<String> debouncedQuery,
    ValueNotifier<Timer?> debounceTimer,
    FocusNode focusNode,
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
            debounceTimer,
            focusNode,
          ),
        ),
        const Gap(AppDimens.spacingXs),
        _buildFiltersButton(context, filters, ref),
      ],
    );
  }

  Widget _buildSearchFooter(
    BuildContext context,
    WidgetRef ref,
    TextEditingController searchController,
    ValueNotifier<String> debouncedQuery,
    ValueNotifier<Timer?> debounceTimer,
    FocusNode focusNode,
  ) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final safePadding = MediaQuery.viewPaddingOf(context).bottom;
    final keyboardInset = (viewInsets - safePadding).clamp(
      0.0,
      double.infinity,
    );
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingMd,
            vertical: AppDimens.spacing2xs,
          ),
          child: FCard.raw(
            style: context.theme.cardStyles.borderless.call,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingSm,
                vertical: AppDimens.spacing2xs,
              ),
              child: _buildSearchBarWithFilters(
                context,
                ref,
                searchController,
                debouncedQuery,
                debounceTimer,
                focusNode,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    WidgetRef ref,
    TextEditingController searchController,
    ValueNotifier<String> debouncedQuery,
    ValueNotifier<Timer?> debounceTimer,
    FocusNode focusNode,
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
          builder: (context, _, child) {
            final backgroundColor = context.theme.colors.muted.withValues(
              alpha: 0.08,
            );
            return DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingSm,
                ),
                child: FTextField(
                  focusNode: focusNode,
                  controller: searchController,
                  hint: Strings.searchPlaceholder,
                  clearable: (value) => !isFetching && value.text.isNotEmpty,
                  textInputAction: TextInputAction.search,
                  onChange: (_) {
                    // WHY: Provider handles debouncing - just trigger rebuild
                    // The searchResultsProvider will debounce internally via Future.delayed
                  },
                  onSubmit: (_) => _commitSearchQuery(
                    searchController.text,
                    debouncedQuery,
                    debounceTimer,
                  ),
                  prefixBuilder: (context, style, states) => Icon(
                    FIcons.search,
                    size: AppDimens.iconSm,
                    color: context.theme.colors.mutedForeground,
                  ),
                  suffixBuilder: isFetching
                      ? (context, style, states) => Semantics(
                          label: Strings.searchingInProgress,
                          liveRegion: true,
                          child: const SizedBox(
                            width: AppDimens.iconSm,
                            height: AppDimens.iconSm,
                            child: FCircularProgress.loader(),
                          ),
                        )
                      : null,
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
        child: GestureDetector(
          onTap: () => _openFiltersSheet(context, filters, ref),
          child: SizedBox(
            width: 56,
            height: 48,
            child: Material(
              color: Colors.transparent,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      FIcons.slidersHorizontal,
                      size: 18,
                      color: context.theme.colors.foreground,
                    ),
                  ),
                  if (hasActiveFilters)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IgnorePointer(
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
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _commitSearchQuery(
    String rawValue,
    ValueNotifier<String> debouncedQuery,
    ValueNotifier<Timer?> debounceTimer,
  ) {
    debounceTimer.value?.cancel();
    debouncedQuery.value = rawValue.trim();
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

  Widget _buildFiltersPanel(
    BuildContext context,
    SearchFilters currentFilters,
    WidgetRef ref,
  ) {
    return FCard.raw(
      style: context.theme.cardStyles.borderless.call,
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
            FTileGroup(
              divider: FItemDivider.indented,
              children: [
                buildAdministrationRouteFilterTile(
                  context,
                  ref,
                  currentFilters,
                ),
                _buildTherapeuticClassFilter(context, currentFilters, ref),
              ],
            ),
          ],
        ),
      ),
    );
  }

  FTileMixin _buildTherapeuticClassFilter(
    BuildContext context,
    SearchFilters currentFilters,
    WidgetRef ref,
  ) {
    final menu = [
      FSelectTile<AtcLevel1?>(
        title: Text(Strings.allClasses, style: context.theme.typography.base),
        value: null,
      ),
      ...AtcLevel1.values.map(
        (atcClass) => FSelectTile<AtcLevel1?>(
          title: Text(atcClass.label, style: context.theme.typography.base),
          subtitle: Text(atcClass.code),
          value: atcClass,
        ),
      ),
    ];

    return FSelectMenuTile<AtcLevel1?>(
      initialValue: currentFilters.atcClass,
      title: Text(
        Strings.therapeuticClassFilter,
        style: context.theme.typography.base,
      ),
      detailsBuilder: (tileContext, values, _) {
        final value = values.isNotEmpty ? values.first : null;
        if (value == null) {
          return Text(
            Strings.allClasses,
            style: tileContext.theme.typography.sm.copyWith(
              color: tileContext.theme.colors.mutedForeground,
            ),
          );
        }
        return Text(
          value.label,
          style: tileContext.theme.typography.sm.copyWith(
            color: tileContext.theme.colors.mutedForeground,
          ),
        );
      },
      maxHeight: 320,
      menu: menu,
      onChange: (values) {
        final nextValue = values.isNotEmpty ? values.first : null;
        ref
            .read(searchFiltersProvider.notifier)
            .updateFilters(currentFilters.copyWith(atcClass: nextValue));
        Navigator.of(context).maybePop();
      },
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
        final itemCount = data.items.length + (data.isLoadingMore ? 1 : 0);
        sliver = SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index == data.items.length) {
              return const Padding(
                padding: EdgeInsets.all(AppDimens.spacingMd),
                child: Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: FCircularProgress.loader(),
                  ),
                ),
              );
            }

            final group = data.items[index];
            final hasPrinciples = group.commonPrincipes.isNotEmpty;
            final principles = hasPrinciples
                ? group.commonPrincipes
                : Strings.notDetermined;
            final badgeStyles = context.theme.badgeStyles;
            final princepsBadgeStyle = badgeStyles is PharmaBadgeStyles
                ? badgeStyles.princeps
                : badgeStyles.secondary;
            final genericBadgeStyle = badgeStyles is PharmaBadgeStyles
                ? badgeStyles.generic
                : badgeStyles.primary;

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingMd,
                vertical: AppDimens.spacing2xs,
              ),
              child: Semantics(
                button: true,
                label:
                    'Groupe ${group.groupId}, princeps ${group.princepsReferenceName}, principes actifs $principles',
                child: FCard.raw(
                  style: context.theme.cardStyles.borderless.call,
                  child: GestureDetector(
                    onTap: () => GroupDetailRoute(
                      groupId: group.groupId,
                    ).push<void>(context),
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimens.spacingMd),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Princeps section (left)
                          Expanded(
                            child: _buildGroupSection(
                              context,
                              badge: FBadge(
                                style: princepsBadgeStyle.call,
                                child: Text(
                                  Strings.princeps.substring(0, 1),
                                  style: context.theme.typography.xs,
                                ),
                              ),
                              label: Strings.princeps,
                              name: group.princepsReferenceName,
                              principles: principles,
                              showPrinciples:
                                  false, // Don't show principles on left
                            ),
                          ),
                          // Divider
                          Container(
                            width: 1,
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppDimens.spacingMd,
                            ),
                            color: context.theme.colors.border,
                          ),
                          // Generics section (right)
                          Expanded(
                            child: _buildGroupSection(
                              context,
                              badge: FBadge(
                                style: genericBadgeStyle.call,
                                child: Text(
                                  Strings.generics.substring(0, 1),
                                  style: context.theme.typography.xs,
                                ),
                              ),
                              label: Strings.generics,
                              principles: principles,
                              principlesAsMain:
                                  true, // Show principles as main content
                              isMuted: true,
                            ),
                          ),
                          // Chevron icon - centered vertically and compact
                          const Gap(AppDimens.spacing2xs),
                          Center(
                            child: Icon(
                              FIcons.chevronRight,
                              size: AppDimens.iconXs,
                              color: context.theme.colors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }, childCount: itemCount),
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
              style: context.theme.cardStyles.borderless.call,
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

    return _wrapSliverWithKey(
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final result = results[index];
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimens.spacing2xs,
              ),
              child: Semantics(
                button: true,
                label: _searchResultSemantics(result),
                child: _buildSearchResultCard(context, result, ref),
              ),
            );
          }, childCount: results.length),
        ),
      ),
      key,
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

  Widget _buildSearchResultCard(
    BuildContext context,
    SearchResultItem result,
    WidgetRef ref,
  ) {
    return result.when(
      groupResult: (group) {
        final principles = group.commonPrincipes.isNotEmpty
            ? group.commonPrincipes
            : Strings.notDetermined;
        final badgeStyles = context.theme.badgeStyles;
        final princepsBadgeStyle = badgeStyles is PharmaBadgeStyles
            ? badgeStyles.princeps.call
            : badgeStyles.secondary.call;

        return FCard.raw(
          style: context.theme.cardStyles.borderless.call,
          child: GestureDetector(
            onTap: () =>
                GroupDetailRoute(groupId: group.groupId).push<void>(context),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spacingMd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Princeps section (left)
                  Expanded(
                    child: _buildGroupSection(
                      context,
                      badge: FBadge(
                        style: princepsBadgeStyle,
                        child: Text(
                          Strings.princeps.substring(0, 1),
                          style: context.theme.typography.xs,
                        ),
                      ),
                      label: Strings.princeps,
                      name: extractPrincepsLabel(group.princepsReferenceName),
                      principles: principles,
                      showPrinciples: false,
                    ),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spacingMd,
                    ),
                    color: context.theme.colors.border,
                  ),
                  // Principles section (right) - show principles as main (no generic badge/label)
                  Expanded(
                    child: _buildGroupSection(
                      context,
                      badge: const SizedBox.shrink(),
                      label: '',
                      principles: principles,
                      principlesAsMain: true,
                      isMuted: true,
                    ),
                  ),
                  // Chevron icon
                  const Gap(AppDimens.spacing2xs),
                  Icon(
                    FIcons.chevronRight,
                    size: AppDimens.iconXs,
                    color: context.theme.colors.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      princepsResult: (princeps, generics, groupId, commonPrinciples) {
        final principles = commonPrinciples.isNotEmpty
            ? commonPrinciples
            : Strings.notDetermined;
        final badgeStyles = context.theme.badgeStyles;
        final princepsBadgeStyle = badgeStyles is PharmaBadgeStyles
            ? badgeStyles.princeps.call
            : badgeStyles.secondary.call;

        return FCard.raw(
          style: context.theme.cardStyles.borderless.call,
          child: GestureDetector(
            onTap: () => GroupDetailRoute(groupId: groupId).push<void>(context),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spacingMd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Princeps section (left)
                  Expanded(
                    child: _buildGroupSection(
                      context,
                      badge: FBadge(
                        style: princepsBadgeStyle,
                        child: Text(
                          Strings.princeps.substring(0, 1),
                          style: context.theme.typography.xs,
                        ),
                      ),
                      label: Strings.princeps,
                      name: princeps.princepsDeReference.isNotEmpty
                          ? extractPrincepsLabel(princeps.princepsDeReference)
                          : getDisplayTitle(princeps),
                      principles: principles,
                      showPrinciples: false,
                    ),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spacingMd,
                    ),
                    color: context.theme.colors.border,
                  ),
                  // Principles section (right) - show principles as main (no generic badge/label)
                  Expanded(
                    child: _buildGroupSection(
                      context,
                      badge: const SizedBox.shrink(),
                      label: '',
                      principles: principles,
                      principlesAsMain: true,
                      isMuted: true,
                    ),
                  ),
                  // Chevron icon
                  const Gap(AppDimens.spacing2xs),
                  Icon(
                    FIcons.chevronRight,
                    size: AppDimens.iconXs,
                    color: context.theme.colors.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      genericResult: (generic, princepsList, groupId, commonPrinciples) {
        final principles = commonPrinciples.isNotEmpty
            ? commonPrinciples
            : Strings.notDetermined;
        final badgeStyles = context.theme.badgeStyles;
        final princepsBadgeStyle = badgeStyles is PharmaBadgeStyles
            ? badgeStyles.princeps.call
            : badgeStyles.secondary.call;

        return FCard.raw(
          style: context.theme.cardStyles.borderless.call,
          child: GestureDetector(
            onTap: () => GroupDetailRoute(groupId: groupId).push<void>(context),
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.spacingMd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Princeps section (left) - show first princeps name
                  Expanded(
                    child: _buildGroupSection(
                      context,
                      badge: FBadge(
                        style: princepsBadgeStyle,
                        child: Text(
                          Strings.princeps.substring(0, 1),
                          style: context.theme.typography.xs,
                        ),
                      ),
                      label: Strings.princeps,
                      name: princepsList.isNotEmpty
                          ? getDisplayTitle(princepsList.first)
                          : null,
                      principles: principles,
                      showPrinciples: false,
                    ),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spacingMd,
                    ),
                    color: context.theme.colors.border,
                  ),
                  // Principles section (right) - show principles as main (no generic badge)
                  Expanded(
                    child: _buildGroupSection(
                      context,
                      badge: const SizedBox.shrink(),
                      label: '',
                      principles: principles,
                      principlesAsMain: true,
                      isMuted: true,
                    ),
                  ),
                  // Chevron icon
                  const Gap(AppDimens.spacing2xs),
                  Icon(
                    FIcons.chevronRight,
                    size: AppDimens.iconXs,
                    color: context.theme.colors.mutedForeground,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      standaloneResult:
          (cisCode, summary, representativeCip, commonPrinciples) {
            final principles = commonPrinciples.isNotEmpty
                ? commonPrinciples
                : Strings.notDetermined;
            final badgeStyles = context.theme.badgeStyles;
            final standaloneBadgeStyle = badgeStyles.primary.call;

            return FCard.raw(
              style: context.theme.cardStyles.borderless.call,
              child: GestureDetector(
                onTap: () => _handleSearchResultTap(context, result),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.spacingMd),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Standalone section (left) - show medication name
                      Expanded(
                        child: _buildGroupSection(
                          context,
                          badge: FBadge(
                            style: standaloneBadgeStyle,
                            child: Text(
                              Strings.uniqueMedicationBadge.substring(0, 1),
                              style: context.theme.typography.xs,
                            ),
                          ),
                          label: Strings.uniqueMedicationBadge,
                          name: summary.nomCanonique,
                          principles: principles,
                          showPrinciples: false,
                        ),
                      ),
                      // Divider
                      Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spacingMd,
                        ),
                        color: context.theme.colors.border,
                      ),
                      // Principles section (right) - show principles as main
                      Expanded(
                        child: _buildGroupSection(
                          context,
                          badge: const SizedBox.shrink(),
                          label: '',
                          principles: principles,
                          principlesAsMain: true,
                          isMuted: true,
                        ),
                      ),
                      // Chevron icon
                      const Gap(AppDimens.spacing2xs),
                      Icon(
                        FIcons.chevronRight,
                        size: AppDimens.iconXs,
                        color: context.theme.colors.mutedForeground,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
    );
  }

  String _searchResultSemantics(SearchResultItem result) {
    return result.when(
      groupResult: (group) =>
          'Groupe ${group.groupId}, princeps ${group.princepsReferenceName}, principes actifs ${group.commonPrincipes.isEmpty ? "non déterminé" : group.commonPrincipes}',
      princepsResult: (princeps, generics, groupId, _) =>
          Strings.searchResultSemanticsForPrinceps(
            princeps.nomCanonique,
            generics.length,
          ),
      genericResult: (generic, princepsList, groupId, _) =>
          Strings.searchResultSemanticsForGeneric(
            generic.nomCanonique,
            princepsList.length,
          ),
      standaloneResult: (cisCode, summary, representativeCip, _) =>
          '${Strings.medication} ${summary.nomCanonique}',
    );
  }

  void _handleSearchResultTap(BuildContext context, SearchResultItem result) {
    result.when(
      groupResult: (group) =>
          GroupDetailRoute(groupId: group.groupId).push<void>(context),
      princepsResult: (princeps, generics, groupId, _) =>
          GroupDetailRoute(groupId: groupId).push<void>(context),
      genericResult: (generic, princepsList, groupId, _) =>
          GroupDetailRoute(groupId: groupId).push<void>(context),
      standaloneResult: (cisCode, summary, representativeCip, _) =>
          showAdaptiveOverlay<void>(
            context: context,
            builder: (overlayContext) => _buildStandaloneDetailOverlay(
              overlayContext,
              summary,
              representativeCip,
            ),
          ),
    );
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
        style: context.theme.cardStyles.borderless.call,
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
