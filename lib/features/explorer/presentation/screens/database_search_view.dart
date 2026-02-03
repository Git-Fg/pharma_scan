import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/hooks/use_app_header.dart';
import 'package:pharma_scan/core/hooks/use_tab_reselection.dart';
import 'package:pharma_scan/core/providers/initialization_provider.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/cluster_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/utils/drawer_utils.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/alphabet_sidebar.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/cluster_tile.dart'
    hide Strings;
import 'package:pharma_scan/features/explorer/presentation/widgets/filters/administration_route_filter_tile.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DatabaseSearchView extends HookConsumerWidget {
  const DatabaseSearchView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    final debouncedQuery = useState('');
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    // Controller to maintain input text across rebuilds
    final searchController = useTextEditingController();

    // Sync controller text with debounced query
    useEffect(() {
      void listener() {
        if (searchController.text != debouncedQuery.value) {
          debouncedQuery.value = searchController.text;
        }
      }

      searchController.addListener(listener);
      return () => searchController.removeListener(listener);
    }, [searchController]);

    // Use ItemScrollController for jump-to functionality
    final itemScrollController = useMemoized(() => ItemScrollController());
    final itemPositionsListener = useMemoized(
      () => ItemPositionsListener.create(),
    );

    // NOTE: useTabReselection is not compatible with ItemScrollController directly.
    final scrollController = useScrollController();
    useTabReselection(ref: ref, controller: scrollController, tabIndex: 1);

    final currentQuery = debouncedQuery.value;
    final clusterResults = ref.watch(clusterSearchProvider(currentQuery));
    final initStepAsync = ref.watch(initializationStepProvider);

    final initStep = initStepAsync.value;
    if (initStep != null && initStep != .ready && initStep != .error) {
      return const Center(
        child: StatusView(
          type: .loading,
          icon: LucideIcons.loader,
          title: Strings.initializationInProgress,
          description: Strings.initializationDescription,
        ),
      );
    }

    useAppHeader(
      title: Semantics(
        header: true,
        label: Strings.explorer,
        child: Text(Strings.explorer, style: context.typo.h4),
      ),
    );

    return Column(
      key: const Key(TestTags.explorerScreen),
      children: [
        Expanded(
          child: clusterResults.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: StatusView(
                type: .error,
                title: 'Erreur de chargement',
                description: error.toString(),
                action: ShadButton.ghost(
                  child: const Text('Réessayer'),
                  onPressed: () =>
                      ref.refresh(clusterSearchProvider(currentQuery)),
                ),
              ),
            ),
            data: (clusters) {
              if (clusters.isEmpty) {
                return const Center(child: Text('Aucun résultat trouvé'));
              }

              // Compute letter indices for the sidebar only if not searching
              final letterIndices = useMemoized(() {
                if (currentQuery.isNotEmpty) return <String, int>{};
                final indices = <String, int>{};
                for (var i = 0; i < clusters.length; i++) {
                  final cluster = clusters[i];
                  // Use subtitle (Princeps) for grouping
                  final sortKey = cluster.subtitle.isNotEmpty
                      ? cluster.subtitle
                      : cluster.title;
                  if (sortKey.isNotEmpty) {
                    final firstLetter = sortKey[0].toUpperCase();
                    // Basic normalization or just taking the first char
                    // Might need diacritic removal if strict A-Z is required
                    if (!indices.containsKey(firstLetter)) {
                      indices[firstLetter] = i;
                    }
                  }
                }
                return indices;
              }, [clusters, currentQuery]);

              return Stack(
                children: [
                  ScrollablePositionedList.builder(
                    itemCount: clusters.length,
                    itemScrollController: itemScrollController,
                    itemPositionsListener: itemPositionsListener,
                    padding: const .only(bottom: 100, right: 48),
                    itemBuilder: (context, index) {
                      final cluster = clusters[index];
                      // Determine if we should show a section header
                      String? headerLetter;
                      if (currentQuery.isEmpty) {
                        final currentKey =
                            (cluster.subtitle.isNotEmpty
                                    ? cluster.subtitle
                                    : cluster.title)
                                .toUpperCase();
                        if (currentKey.isNotEmpty) {
                          final currentLetter = currentKey[0];
                          if (index == 0) {
                            headerLetter = currentLetter;
                          } else {
                            final prevCluster = clusters[index - 1];
                            final prevKey =
                                (prevCluster.subtitle.isNotEmpty
                                        ? prevCluster.subtitle
                                        : prevCluster.title)
                                    .toUpperCase();
                            if (prevKey.isEmpty ||
                                prevKey[0] != currentLetter) {
                              headerLetter = currentLetter;
                            }
                          }
                        }
                      }

                      return Column(
                        crossAxisAlignment: .start,
                        children: [
                          if (headerLetter != null &&
                              RegExp(r'[A-Z]').hasMatch(headerLetter))
                            Padding(
                              padding: const .fromLTRB(16, 16, 16, 8),
                              child: Text(
                                headerLetter,
                                style: context.typo.h2.copyWith(
                                  color: context.colors.primary,
                                ),
                              ),
                            ),
                          ClusterTile(
                            entity: cluster,
                            onTap: () =>
                                openMedicationDrawer(context, cluster.id),
                          ),
                        ],
                      );
                    },
                  ),
                  if (currentQuery.isEmpty)
                    AlphabetSidebar(
                      onLetterChanged: (letter) {
                        // Find closest index
                        final index = letterIndices[letter];
                        if (index != null) {
                          itemScrollController.jumpTo(index: index);
                        } else {
                          // Try to find the next closest letter
                          final sortedKeys = letterIndices.keys.toList()
                            ..sort();
                          final nextKey = sortedKeys.firstWhere(
                            (k) => k.compareTo(letter) > 0,
                            orElse: () => '',
                          );
                          if (nextKey.isNotEmpty) {
                            itemScrollController.jumpTo(
                              index: letterIndices[nextKey]!,
                            );
                          }
                        }
                      },
                    ),
                ],
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: .only(
              left: 16,
              right: 16,
              bottom: viewInsetsBottom > 0 ? viewInsetsBottom : 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ShadInput(
                    controller: searchController,
                    placeholder: const Text(
                      'Rechercher par nom, CIP, ou substance...',
                    ),
                    leading: const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(LucideIcons.search, size: 18),
                    ),
                  ),
                ),
                const Gap(8),
                ShadIconButton.outline(
                  icon: const Icon(LucideIcons.listFilter),
                  onPressed: () => _showFilterSheet(context, ref),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    final currentFilters = ref.read(searchFiltersProvider);

    showShadSheet<void>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtres', style: Theme.of(context).textTheme.titleLarge),
            const Gap(16),
            AdministrationRouteFilterTile(currentFilters: currentFilters),
            const Gap(16),
            ShadButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
  }
}
