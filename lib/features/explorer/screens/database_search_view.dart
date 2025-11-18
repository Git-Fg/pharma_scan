// lib/features/explorer/screens/database_search_view.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/features/explorer/models/search_result_item_model.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/features/explorer/providers/group_cluster_provider.dart';
import 'package:pharma_scan/features/explorer/providers/search_provider.dart';
import 'package:pharma_scan/features/explorer/screens/cluster_detail_view.dart';
import 'package:pharma_scan/features/explorer/screens/group_explorer_view.dart';

class DatabaseSearchView extends ConsumerStatefulWidget {
  const DatabaseSearchView({super.key});

  @override
  ConsumerState<DatabaseSearchView> createState() => DatabaseSearchViewState();
}

class DatabaseSearchViewState extends ConsumerState<DatabaseSearchView> {
  Map<String, dynamic>? _stats;
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _dbService = sl<DatabaseService>();
  Timer? _searchDebounce;
  static const _searchDebounceDuration = Duration(milliseconds: 300);
  String _activeQuery = '';

  late ScrollController _scrollController;
  late ScrollController _searchScrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _searchScrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_refreshSearchUi);
    _loadStats();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_refreshSearchUi)
      ..dispose();
    _scrollController.dispose();
    _searchScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await _dbService.getDatabaseStats();
    if (mounted) {
      setState(() => _stats = stats);
    }
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
    final clusters = ref.watch(groupClusterProvider);
    final searchResults = ref.watch(searchResultsProvider(_activeQuery));
    final hasSearchText = _searchController.text.isNotEmpty;
    final isDebouncing = _searchDebounce?.isActive ?? false;
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              child: Column(
                children: [
                  if (_stats != null) _buildStatsHeader(theme),
                  const SizedBox(height: 16),
                  _buildSearchBar(theme),
                  const SizedBox(height: 8),
                  Expanded(
                    child: !hasSearchText
                        ? _buildClusterLibraryView(theme, clusters)
                        : isDebouncing
                        ? _buildSkeletonList(theme)
                        : searchResults.when(
                            data: (items) => _buildSearchResults(theme, items),
                            loading: () => _buildSkeletonList(theme),
                            error: (error, _) =>
                                _buildSearchError(theme, error),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(ShadThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(theme, 'Princeps', '${_stats!['total_princeps']}'),
          _buildStatItem(theme, 'Génériques', '${_stats!['total_generiques']}'),
          _buildStatItem(
            theme,
            'Principes Actifs',
            '${_stats!['total_principes']}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(ShadThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(value, style: theme.textTheme.h4),
        Text(label, style: theme.textTheme.muted),
      ],
    );
  }

  Widget _buildSearchBar(ShadThemeData theme) {
    final hasText = _searchController.text.isNotEmpty;
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        ShadInput(
          controller: _searchController,
          placeholder: const Text('Rechercher par nom, CIP, ou principe...'),
          onChanged: _onSearchChanged,
          padding: hasText ? const EdgeInsets.only(right: 40) : null,
        ),
        if (hasText)
          ShadButton.ghost(
            onPressed: _clearSearchField,
            leading: const Icon(LucideIcons.x, size: 16),
            child: const SizedBox.shrink(),
          ),
      ],
    );
  }

  Widget _buildSearchResults(
    ShadThemeData theme,
    List<SearchResultItem> results,
  ) {
    if (results.isEmpty) {
      return Center(
        child: Text('Aucun résultat trouvé.', style: theme.textTheme.muted),
      );
    }
    return Scrollbar(
      controller: _searchScrollController,
      thumbVisibility: true,
      child: ListView.separated(
        controller: _searchScrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: results.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final result = results[index];
          final onTapCallback = result.when(
            princepsResult:
                (princeps, unusedGenerics, groupId, unusedPrinciples) {
              return () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GroupExplorerView(
                      groupId: groupId,
                      onExit: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              };
            },
            genericResult:
                (generic, unusedPrincepsList, groupId, unusedPrinciples) {
              return () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => GroupExplorerView(
                      groupId: groupId,
                      onExit: () => Navigator.of(context).pop(),
                    ),
                  ),
                );
              };
            },
            // WHY: Explicitly return null for standalone results to disable InkWell feedback
            standaloneResult: (unusedMedicament, unusedPrinciples) => null,
          );
          final card = Semantics(
            button: onTapCallback != null,
            label: result.when(
              princepsResult:
                  (princeps, generics, unusedGroupId, unusedPrinciples) =>
                      'Princeps ${princeps.nom} avec ${generics.length} génériques',
              genericResult:
                  (generic, princepsList, unusedGroupId, unusedPrinciples) =>
                      'Générique ${generic.nom} avec ${princepsList.length} princeps',
              standaloneResult: (medicament, unusedPrinciples) =>
                  'Médicament ${medicament.nom}',
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTapCallback,
                borderRadius: BorderRadius.circular(12),
                splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                highlightColor: theme.colorScheme.primary.withValues(
                  alpha: 0.05,
                ),
                child: result.when(
                  princepsResult:
                      (princeps, generics, unusedGroupId, unusedPrinciples) =>
                          _buildPrincepsSearchCard(theme, princeps, generics),
                  genericResult:
                      (
                        generic,
                        princepsList,
                        unusedGroupId,
                        unusedPrinciples,
                      ) =>
                          _buildGenericSearchCard(theme, generic, princepsList),
                  standaloneResult: (medicament, unusedPrinciples) =>
                      _buildStandaloneSearchCard(theme, medicament),
                ),
              ),
            ),
          );
          return card
              .animate()
              .fadeIn(duration: 200.ms, delay: (index * 40).ms)
              .slideY(begin: 0.05, curve: Curves.easeOutCubic);
        },
      ),
    );
  }

  Widget _buildSearchError(ShadThemeData theme, Object error) {
    return Center(
      child: Text(
        'Une erreur est survenue pendant la recherche.\n${error.toString()}',
        style: theme.textTheme.muted,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildClusterLibraryView(
    ShadThemeData theme,
    AsyncValue<ClusterLibraryState> clusters,
  ) {
    if (clusters.isLoading) {
      return _buildSkeletonList(theme);
    }
    final data = clusters.asData?.value;
    if (clusters.hasError && (data == null || data.items.isEmpty)) {
      return _buildClusterError(theme);
    }
    if (data == null || data.items.isEmpty) {
      return Center(
        child: Text(
          'Aucun cluster de produits à afficher.',
          style: theme.textTheme.muted,
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: data.items.length + (data.isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) {
        if (index == data.items.length) {
          return const SizedBox.shrink();
        }
        return const SizedBox(height: 12);
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
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ClusterDetailView(
                      clusterKey: cluster.clusterKey,
                      princepsBrandName: cluster.princepsBrandName,
                      activeIngredients: cluster.activeIngredients,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
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
                            'Principe(s) actif(s)',
                            style: theme.textTheme.small.copyWith(
                              color: theme.colorScheme.mutedForeground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cluster.activeIngredients.isEmpty
                                ? 'Non déterminé'
                                : cluster.activeIngredients.join(', '),
                            style: theme.textTheme.p,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ShadBadge(
                                child: Text(
                                  '${cluster.groupCount} groupe(s)',
                                  style: theme.textTheme.small.copyWith(
                                    color: theme.colorScheme.primaryForeground,
                                  ),
                                ),
                              ),
                              ShadBadge.secondary(
                                child: Text(
                                  '${cluster.memberCount} spécialités',
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
                            'Marque princeps',
                            style: theme.textTheme.small.copyWith(
                              color: theme.colorScheme.mutedForeground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cluster.princepsBrandName,
                            style: theme.textTheme.p.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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

  Widget _buildClusterError(ShadThemeData theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ShadCard(
          title: Text('Erreur de chargement', style: theme.textTheme.h4),
          description: Text(
            'Impossible de récupérer la bibliothèque des clusters. Vérifiez votre connexion puis réessayez.',
            style: theme.textTheme.muted,
          ),
          footer: Align(
            alignment: Alignment.centerRight,
            child: ShadButton(
              onPressed: () => ref.invalidate(groupClusterProvider),
              child: const Text('Réessayer'),
            ),
          ),
          child: const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildSkeletonList(ShadThemeData theme) {
    final placeholderColor = theme.colorScheme.muted.withValues(alpha: 0.3);
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 4,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final card = ShadCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBlock(
                      height: 12,
                      width: 120,
                      color: placeholderColor,
                    ),
                    const SizedBox(height: 12),
                    _SkeletonBlock(height: 16, color: placeholderColor),
                    const SizedBox(height: 8),
                    _SkeletonBlock(
                      height: 16,
                      width: 160,
                      color: placeholderColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _SkeletonBlock(height: 16, width: 24, color: placeholderColor),
            ],
          ),
        );
        return card
            .animate()
            .fadeIn(duration: 180.ms, delay: (index * 40).ms)
            .slideY(begin: 0.04, curve: Curves.easeOut)
            .shimmer(duration: 1200.ms);
      },
    );
  }

  Widget _buildStandaloneSearchCard(
    ShadThemeData theme,
    Medicament medicament,
  ) {
    return ShadCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Médicament',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(medicament.nom, style: theme.textTheme.p),
                if (medicament.principesActifs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Principe(s) actif(s):',
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    medicament.principesActifs.join(', '),
                    style: theme.textTheme.muted,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: theme.colorScheme.mutedForeground,
          ),
        ],
      ),
    );
  }

  Widget _buildPrincepsSearchCard(
    ShadThemeData theme,
    Medicament princeps,
    List<Medicament> generics,
  ) {
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
                  'Princeps',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  princeps.nom,
                  style: theme.textTheme.p.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (princeps.principesActifs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Principe(s) actif(s):',
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    princeps.principesActifs.join(', '),
                    style: theme.textTheme.muted,
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
                  'Génériques (${generics.length})',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ...generics.map(
                  (generic) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${generic.nom}',
                      style: theme.textTheme.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
                  'Générique',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  generic.nom,
                  style: theme.textTheme.p.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (generic.principesActifs.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Principe(s) actif(s):',
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    generic.principesActifs.join(', '),
                    style: theme.textTheme.muted,
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
                  'Princeps (${princeps.length})',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ...princeps.map(
                  (princeps) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${princeps.nom}',
                      style: theme.textTheme.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: theme.colorScheme.mutedForeground,
          ),
        ],
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
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
