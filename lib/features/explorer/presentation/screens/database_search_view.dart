import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/scroll_to_top_fab.dart';
import 'package:pharma_scan/core/widgets/testable.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
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
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottomPadding = MediaQuery.paddingOf(context).bottom;
    final bottomSpace = viewInsetsBottom > 0
        ? viewInsetsBottom
        : safeBottomPadding;

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

    return _KeepAliveWrapper(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: context.shadColors.background,
        appBar: AppBar(
          title: Text(
            Strings.explorer,
            style: context.shadTextTheme.h4,
          ),
          elevation: 0,
          backgroundColor: context.shadColors.background,
          foregroundColor: context.shadColors.foreground,
          actions: [
            Testable(
              id: TestTags.navSettings,
              child: ShadIconButton.ghost(
                icon: const Icon(LucideIcons.settings),
                onPressed: () =>
                    AutoRouter.of(context).push(const SettingsRoute()),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            // Main scrollable content
            CustomScrollView(
              key: const PageStorageKey('explorer_list'),
              controller: scrollController,
              slivers: [
                // Main content (stats, groups, search results)
                ExplorerContentList(
                  groups: groups,
                  searchResults: searchResults,
                  hasSearchText: hasSearchText,
                  isSearching: isSearching,
                  currentQuery: currentQuery,
                ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    bottom: AppDimens.searchBarHeaderHeight + bottomSpace,
                  ),
                ),
              ],
            ),
            Positioned(
              right: AppDimens.spacingMd,
              bottom:
                  AppDimens.searchBarHeaderHeight +
                  bottomSpace +
                  AppDimens.spacingSm,
              child: ScrollToTopFab(controller: scrollController),
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
      ),
    );
  }
}

class _KeepAliveWrapper extends HookWidget {
  const _KeepAliveWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    useAutomaticKeepAlive();
    return child;
  }
}
