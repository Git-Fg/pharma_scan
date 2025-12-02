import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/database_stats_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/explorer_content_list.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/explorer_search_bar.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DatabaseSearchView extends HookConsumerWidget {
  const DatabaseSearchView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();
    final debouncedQuery = useState('');

    useEffect(() {
      void onScroll() {
        if (!scrollController.hasClients) return;
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
          unawaited(ref.read(genericGroupsProvider.notifier).loadMore());
        }
      }

      scrollController.addListener(onScroll);
      return () => scrollController.removeListener(onScroll);
    }, [scrollController]);

    final groups = ref.watch(genericGroupsProvider);
    final currentQuery = debouncedQuery.value;
    final searchResults = ref.watch(searchResultsProvider(currentQuery));
    final databaseStats = ref.watch(databaseStatsProvider);
    final hasSearchText = currentQuery.isNotEmpty;
    final isSearching = hasSearchText;
    final initStepAsync = ref.watch(initializationStepProvider);

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
              ExplorerContentList(
                databaseStats: databaseStats,
                groups: groups,
                searchResults: searchResults,
                hasSearchText: hasSearchText,
                isSearching: isSearching,
                currentQuery: currentQuery,
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom:
                      AppDimens.searchBarHeaderHeight +
                      MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          ),
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
}
