import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/providers/navigation_provider.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/grouped_content_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/explorer_content_list.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/explorer_search_bar.dart';
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DatabaseSearchView extends HookConsumerWidget {
  const DatabaseSearchView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemScrollController = useMemoized(
      ItemScrollController.new,
      const [],
    );
    final itemPositionsListener = useMemoized(
      ItemPositionsListener.create,
      const [],
    );
    final debouncedQuery = useState('');
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottomPadding = MediaQuery.paddingOf(context).bottom;
    final bottomSpace = viewInsetsBottom > 0
        ? viewInsetsBottom
        : safeBottomPadding;
    final listBottomPadding =
        AppDimens.searchBarHeaderHeight + bottomSpace + AppDimens.spacingSm;

    useEffect(() {
      final cancel = ref.listenManual<TabReselectionSignal>(
        tabReselectionProvider,
        (previous, next) {
          if (next.tabIndex == 1 && itemScrollController.isAttached) {
            unawaited(
              itemScrollController.scrollTo(
                index: 0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              ),
            );
          }
        },
      );
      return cancel.close;
    }, [itemScrollController]);

    final groups = ref.watch(genericGroupsProvider);
    final currentQuery = debouncedQuery.value;
    final searchResults = ref.watch(searchResultsProvider(currentQuery));
    final hasSearchText = currentQuery.isNotEmpty;
    final isSearching = hasSearchText;
    final initStepAsync = ref.watch(initializationStepProvider);

    final groupedContent = ref.watch(groupedExplorerContentProvider);
    final isIndexing = groupedContent.isLoading || groupedContent.isRefreshing;
    final groupedData = groupedContent.when(
      skipLoadingOnReload: true,
      data: (value) => value,
      loading: () => (
        groupedItems: List<Object>.empty(),
        letterIndex: <String, int>{},
      ),
      error: (error, stackTrace) => (
        groupedItems: List<Object>.empty(),
        letterIndex: <String, int>{},
      ),
    );

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
        ),
        body: Column(
          children: [
            if (isIndexing)
              PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: 1,
                  minHeight: 2,
                  backgroundColor: context.shadColors.border,
                  color: context.shadColors.primary,
                ),
              ),
            Expanded(
              child: ExplorerContentList(
                groups: groups,
                groupedItems: groupedData.groupedItems,
                searchResults: searchResults,
                hasSearchText: hasSearchText,
                isSearching: isSearching,
                currentQuery: currentQuery,
                bottomPadding: listBottomPadding,
                itemScrollController: itemScrollController,
                itemPositionsListener: itemPositionsListener,
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppDimens.spacingMd,
                  right: AppDimens.spacingMd,
                  bottom: viewInsetsBottom > 0
                      ? viewInsetsBottom
                      : AppDimens.spacingSm,
                ),
                child: ExplorerSearchBar(
                  key: const ValueKey('searchBar'),
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
