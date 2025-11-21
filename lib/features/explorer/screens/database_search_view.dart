// lib/features/explorer/screens/database_search_view.dart
import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/config/app_config.dart';
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/core/utils/adaptive_overlay.dart';
import 'package:pharma_scan/core/utils/app_animations.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_search_input.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/models/search_result_item_model.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pharma_scan/features/explorer/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/widgets/standalone_search_result.dart';
import 'package:pharma_scan/features/explorer/providers/database_stats_provider.dart';
import 'package:pharma_scan/features/explorer/providers/group_cluster_provider.dart';
import 'package:pharma_scan/features/explorer/providers/pharmaceutical_forms_provider.dart';
import 'package:pharma_scan/features/explorer/providers/search_provider.dart';

class DatabaseSearchView extends ConsumerStatefulWidget {
  const DatabaseSearchView({super.key});

  @override
  ConsumerState<DatabaseSearchView> createState() => DatabaseSearchViewState();
}

@visibleForTesting
List<MapEntry<String, int>> summarizeGenericsByName(List<Medicament> generics) {
  final counts = <String, int>{};
  for (final generic in generics) {
    final name = generic.nom;
    if (name.isEmpty) continue;
    counts.update(name, (value) => value + 1, ifAbsent: () => 1);
  }

  final entries = counts.entries.toList()
    ..sort((a, b) {
      final countComparison = b.value.compareTo(a.value);
      if (countComparison != 0) return countComparison;
      return compareNatural(a.key, b.key);
    });

  return entries;
}

class DatabaseSearchViewState extends ConsumerState<DatabaseSearchView> {
  static const double _searchHeaderHeight = 68;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  static const Duration _searchDebounceDuration = AppConfig.searchDebounce;
  String _activeQuery = '';
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_refreshSearchUi);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_refreshSearchUi)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final clusterState = ref.read(groupClusterProvider);
      final data = clusterState.value;
      if (data == null || !data.hasMore || data.isLoadingMore) {
        return;
      }
      ref.read(groupClusterProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() => _activeQuery = '');
      return;
    }

    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) return;
      setState(() => _activeQuery = query.trim());
    });
  }

  void _clearSearchField() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() => _activeQuery = '');
  }

  void _refreshSearchUi() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final filters = ref.watch(searchFiltersProvider);
    final clusters = ref.watch(groupClusterProvider);
    final searchResults = ref.watch(searchResultsProvider(_activeQuery));
    final databaseStats = ref.watch(databaseStatsProvider);
    final hasSearchText = _searchController.text.isNotEmpty;
    final isDebouncing = _searchDebounce?.isActive ?? false;
    final isSearching = hasSearchText && !isDebouncing;
    final showFiltersBar = filters.hasActiveFilters;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  databaseStats.when(
                    data: (stats) => SliverToBoxAdapter(
                      child: Column(
                        children: [
                          _buildStatsHeader(theme, stats),
                          const Gap(16),
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
                      child: _buildSearchBarWithFilters(theme),
                    ),
                  ),
                  const SliverToBoxAdapter(child: Gap(8)),
                  if (!hasSearchText)
                    _buildClusterLibrarySliver(
                      theme,
                      clusters,
                      key: const ValueKey('cluster_library_sliver'),
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
                        key: const ValueKey('search_results_sliver'),
                      ),
                      loading: () => _buildSkeletonSliver(
                        theme,
                        key: const ValueKey('search_loading_sliver'),
                      ),
                      error: (error, _) =>
                          _buildSearchErrorSliver(theme, error),
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
                child: _buildActiveFiltersBar(theme, filters),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(ShadThemeData theme, Map<String, dynamic> stats) {
    final statsConfig = [
      (Strings.totalPrinceps, '${stats['total_princeps']}'),
      (Strings.totalGenerics, '${stats['total_generiques']}'),
      (Strings.totalPrinciples, '${stats['total_principes']}'),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          for (var i = 0; i < statsConfig.length; i++) ...[
            Expanded(
              child: ShadCard(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statsConfig[i].$1,
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(6),
                    Text(statsConfig[i].$2, style: theme.textTheme.h4),
                  ],
                ),
              ),
            ),
            if (i != statsConfig.length - 1) const Gap(12),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBarWithFilters(ShadThemeData theme) {
    final filters = ref.watch(searchFiltersProvider);
    return Row(
      children: [
        Expanded(child: _buildSearchBar(theme)),
        const Gap(8),
        _buildFiltersButton(theme, filters),
      ],
    );
  }

  Widget _buildSearchBar(ShadThemeData theme) {
    final isDebouncing = _searchDebounce?.isActive ?? false;
    return Semantics(
      textField: true,
      label: Strings.searchLabel,
      hint: Strings.searchHint,
      value: _searchController.text,
      child: PharmaSearchInput(
        controller: _searchController,
        placeholder: Strings.searchPlaceholder,
        onChanged: _onSearchChanged,
        onClear: _clearSearchField,
        isLoading: isDebouncing,
        loadingLabel: Strings.searchingInProgress,
      ),
    );
  }

  Widget _buildFiltersButton(ShadThemeData theme, SearchFilters filters) {
    final hasActiveFilters = filters.hasActiveFilters;
    final filterCount =
        (filters.procedureType != null ? 1 : 0) +
        (filters.formePharmaceutique != null ? 1 : 0);
    final filterLabel = hasActiveFilters
        ? Strings.editFilters
        : Strings.openFilters;
    final filterValue = hasActiveFilters
        ? Strings.activeFilterCount(filterCount)
        : null;

    return Semantics(
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
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InkWell(
                onTap: () => _openFiltersSheet(theme, filters),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.border),
                    borderRadius: BorderRadius.circular(10),
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
    );
  }

  Future<void> _openFiltersSheet(
    ShadThemeData theme,
    SearchFilters currentFilters,
  ) {
    return showAdaptiveOverlay(
      context: context,
      builder: (overlayContext) => _buildFiltersPanel(theme, currentFilters),
    );
  }

  Widget _buildActiveFiltersBar(ShadThemeData theme, SearchFilters filters) {
    final chips = <Widget>[];
    if (filters.procedureType != null) {
      chips.add(
        ShadBadge.secondary(
          child: Text(
            filters.procedureType == 'Autorisation'
                ? 'Allopathie'
                : 'Homéopathie / Phyto',
            style: theme.textTheme.small,
          ),
        ),
      );
    }
    if (filters.formePharmaceutique != null) {
      chips.add(
        ShadBadge(
          child: Text(
            filters.formePharmaceutique!,
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.primaryForeground,
            ),
          ),
        ),
      );
    }

    final hasChips = chips.isNotEmpty;

    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: hasChips
                ? Wrap(spacing: 8, runSpacing: 8, children: chips)
                : Text(Strings.noActiveFilters, style: theme.textTheme.muted),
          ),
          const Gap(12),
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

  Widget _buildFiltersPanel(ShadThemeData theme, SearchFilters currentFilters) {
    return ShadCard(
      padding: const EdgeInsets.all(16),
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
                  'Réinitialiser',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const Gap(16),
          Text(
            Strings.procedureType,
            style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(8),
          _buildProcedureTypeFilter(theme, currentFilters),
          const Gap(24),
          Text(
            Strings.pharmaceuticalFormFilter,
            style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
          ),
          const Gap(8),
          _buildPharmaceuticalFormFilter(theme, currentFilters),
        ],
      ),
    );
  }

  Widget _buildProcedureTypeFilter(
    ShadThemeData theme,
    SearchFilters currentFilters,
  ) {
    return ShadRadioGroup<String?>(
      initialValue: currentFilters.procedureType,
      onChanged: (value) {
        ref
            .read(searchFiltersProvider.notifier)
            .updateFilters(currentFilters.copyWith(procedureType: value));
      },
      items: const [
        ShadRadio<String?>(value: null, label: Text(Strings.all)),
        ShadRadio<String?>(
          value: 'Autorisation',
          label: Text(Strings.allopathy),
        ),
        ShadRadio<String?>(
          value: 'Enregistrement',
          label: Text(Strings.homeopathy),
        ),
      ],
    );
  }

  Widget _buildPharmaceuticalFormFilter(
    ShadThemeData theme,
    SearchFilters currentFilters,
  ) {
    final formsAsync = ref.watch(pharmaceuticalFormsProvider);

    return formsAsync.when(
      data: (forms) {
        if (forms.isEmpty) {
          return Text(Strings.noFormsAvailable, style: theme.textTheme.muted);
        }

        return ShadSelect<String?>(
          minWidth: double.infinity,
          placeholder: const Text(Strings.allForms),
          initialValue: currentFilters.formePharmaceutique,
          options: [
            const ShadOption<String?>(
              value: null,
              child: Text(Strings.allForms),
            ),
            ...forms.map(
              (form) => ShadOption<String?>(value: form, child: Text(form)),
            ),
          ],
          selectedOptionBuilder: (context, value) {
            if (value == null) {
              return const Text(Strings.allForms);
            }
            return Text(value);
          },
          onChanged: (value) {
            ref
                .read(searchFiltersProvider.notifier)
                .updateFilters(
                  currentFilters.copyWith(formePharmaceutique: value),
                );
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
          Text(Strings.errorLoadingForms, style: theme.textTheme.muted),
    );
  }

  Widget _buildClusterError(ShadThemeData theme) {
    return StatusView(
      type: StatusType.error,
      title: Strings.loadingError,
      description: Strings.clusterLibraryError,
      action: Semantics(
        button: true,
        label: Strings.retryClusterLibrary,
        child: ShadButton(
          onPressed: () => ref.invalidate(groupClusterProvider),
          child: const Text(Strings.retry),
        ),
      ),
    );
  }

  Widget _buildPrincepsSearchCard(
    ShadThemeData theme,
    Medicament princeps,
    List<Medicament> generics,
  ) {
    final summarizedGenerics = summarizeGenericsByName(generics);

    return ShadCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            flex: 2,
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
                const Gap(8),
                Text(
                  princeps.nom,
                  style: theme.textTheme.p.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                if (princeps.principesActifs.isNotEmpty) ...[
                  const Gap(4),
                  Text(
                    'Principe(s) actif(s):',
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    princeps.principesActifs.join(', '),
                    style: theme.textTheme.muted,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              LucideIcons.arrowRightLeft,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Strings.genericCount(generics.length),
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(8),
                ...summarizedGenerics.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      entry.value > 1
                          ? '• ${entry.key} (${entry.value})'
                          : '• ${entry.key}',
                      style: theme.textTheme.muted,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(8),
          Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: theme.colorScheme.mutedForeground,
          ),
        ],
      ),
    );
  }

  Widget _buildGenericSearchCard(
    ShadThemeData theme,
    Medicament generic,
    List<Medicament> princeps,
  ) {
    return ShadCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Strings.genericLabel,
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(8),
                Text(
                  generic.nom,
                  style: theme.textTheme.p.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                if (generic.principesActifs.isNotEmpty) ...[
                  const Gap(4),
                  Text(
                    '${Strings.activeIngredientsLabel}:',
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Gap(4),
                  Text(
                    generic.principesActifs.join(', '),
                    style: theme.textTheme.muted,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              LucideIcons.arrowRightLeft,
              color: theme.colorScheme.mutedForeground,
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Strings.princepsCount(princeps.length),
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(8),
                ...princeps.map(
                  (princeps) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${princeps.nom}',
                      style: theme.textTheme.muted,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(8),
          Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: theme.colorScheme.mutedForeground,
          ),
        ],
      ),
    );
  }

  // Sliver versions for CustomScrollView
  Widget _buildClusterLibrarySliver(
    ShadThemeData theme,
    AsyncValue<ClusterLibraryState> clusters, {
    Key? key,
  }) {
    Widget sliver;
    if (clusters.isLoading) {
      sliver = _buildSkeletonSliver(theme);
    } else {
      final data = clusters.asData?.value;
      if (clusters.hasError && (data == null || data.items.isEmpty)) {
        sliver = SliverToBoxAdapter(child: _buildClusterError(theme));
      } else if (data == null || data.items.isEmpty) {
        sliver = const SliverToBoxAdapter(
          child: StatusView(
            type: StatusType.empty,
            title: Strings.noProductClustersToDisplay,
          ),
        );
      } else {
        sliver = SliverList.separated(
          itemCount: data.items.length + (data.isLoadingMore ? 1 : 0),
          separatorBuilder: (context, index) {
            if (index == data.items.length) {
              return const SizedBox.shrink();
            }
            return const Gap(12);
          },
          itemBuilder: (context, index) {
            if (index == data.items.length) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: const ShadProgress(),
                  ),
                ),
              );
            }
            final cluster = data.items[index];
            return Semantics(
              button: true,
              label:
                  'Cluster ${cluster.princepsBrandName}, principes actifs ${cluster.activeIngredients.join(', ')}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push(
                    AppRoutes.clusterDetail(
                      cluster.clusterKey,
                      brandName: cluster.princepsBrandName,
                      activeIngredients: cluster.activeIngredients,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  highlightColor: theme.colorScheme.primary.withValues(
                    alpha: 0.05,
                  ),
                  child: ShadCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Strings.activeIngredientsLabel,
                                style: theme.textTheme.small.copyWith(
                                  color: theme.colorScheme.mutedForeground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Gap(8),
                              Text(
                                cluster.activeIngredients.isEmpty
                                    ? 'Non déterminé'
                                    : cluster.activeIngredients.join(', '),
                                style: theme.textTheme.p,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 3,
                              ),
                              const Gap(12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ShadBadge(
                                    child: Text(
                                      Strings.groupCount(cluster.groupCount),
                                      style: theme.textTheme.small.copyWith(
                                        color:
                                            theme.colorScheme.primaryForeground,
                                      ),
                                    ),
                                  ),
                                  ShadBadge.secondary(
                                    child: Text(
                                      Strings.memberCount(cluster.memberCount),
                                      style: theme.textTheme.small,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                Strings.brandPrincepsLabel,
                                style: theme.textTheme.small.copyWith(
                                  color: theme.colorScheme.mutedForeground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Gap(8),
                              Text(
                                cluster.princepsBrandName,
                                style: theme.textTheme.p.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                        const Gap(8),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 16,
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
      separatorBuilder: (context, index) => const Gap(12),
      itemBuilder: (context, index) {
        return ShadCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBlock(height: 14, color: placeholderColor),
                    const Gap(8),
                    _SkeletonBlock(height: 16, color: placeholderColor),
                    const Gap(8),
                    _SkeletonBlock(
                      height: 16,
                      width: 120,
                      color: placeholderColor,
                    ),
                  ],
                ),
              ),
              const Gap(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBlock(height: 14, color: placeholderColor),
                    const Gap(8),
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
    List<SearchResultItem> results, {
    Key? key,
  }) {
    if (results.isEmpty) {
      final filters = ref.watch(searchFiltersProvider);
      final hasFilters = filters.hasActiveFilters;
      return _wrapSliverWithKey(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(Strings.noResults, style: theme.textTheme.muted),
                if (hasFilters) ...[
                  const Gap(12),
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
      separatorBuilder: (context, index) => const Gap(12),
      itemBuilder: (context, index) {
        final result = results[index];
        return Semantics(
          button: true,
          label: result.when(
            princepsResult:
                (princeps, generics, unusedGroupId, unusedPrinciples) =>
                    Strings.searchResultSemanticsForPrinceps(
                      princeps.nom,
                      generics.length,
                    ),
            genericResult:
                (generic, princepsList, unusedGroupId, unusedPrinciples) =>
                    Strings.searchResultSemanticsForGeneric(
                      generic.nom,
                      princepsList.length,
                    ),
            standaloneResult: (medicament, unusedPrinciples) =>
                '${Strings.medication} ${medicament.nom}',
          ),
          child: result.when(
            princepsResult:
                (princeps, generics, unusedGroupId, unusedPrinciples) =>
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            context.push(AppRoutes.groupDetail(unusedGroupId)),
                        borderRadius: BorderRadius.circular(12),
                        splashColor: theme.colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        highlightColor: theme.colorScheme.primary.withValues(
                          alpha: 0.05,
                        ),
                        child: _buildPrincepsSearchCard(
                          theme,
                          princeps,
                          generics,
                        ),
                      ),
                    ),
            genericResult:
                (generic, princepsList, unusedGroupId, unusedPrinciples) =>
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            context.push(AppRoutes.groupDetail(unusedGroupId)),
                        borderRadius: BorderRadius.circular(12),
                        splashColor: theme.colorScheme.primary.withValues(
                          alpha: 0.1,
                        ),
                        highlightColor: theme.colorScheme.primary.withValues(
                          alpha: 0.05,
                        ),
                        child: _buildGenericSearchCard(
                          theme,
                          generic,
                          princepsList,
                        ),
                      ),
                    ),
            standaloneResult: (medicament, unusedPrinciples) =>
                StandaloneSearchResult(medicament: medicament),
          ),
        ).animate(delay: (index * 40).ms, effects: AppAnimations.listItemEnter);
      },
    );
    return _wrapSliverWithKey(sliver, key);
  }

  Widget _buildSearchErrorSliver(ShadThemeData theme, Object error) {
    return SliverToBoxAdapter(
      child: StatusView(
        type: StatusType.error,
        title: Strings.searchErrorOccurred,
        description: error.toString(),
        action: ShadButton(
          onPressed: () => ref.invalidate(searchResultsProvider(_activeQuery)),
          child: const Text(Strings.retry),
        ),
      ),
    );
  }

  Widget _wrapSliverWithKey(Widget sliver, Key? key) {
    if (key == null) return sliver;
    return SliverPadding(key: key, padding: EdgeInsets.zero, sliver: sliver);
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
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
