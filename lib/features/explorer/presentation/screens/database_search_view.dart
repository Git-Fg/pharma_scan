import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/providers/navigation_provider.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/scroll_to_top_fab.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/grouped_content_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/alphabet_sidebar.dart';
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
      final cancel = ref.listenManual<TabReselectionSignal>(
        tabReselectionProvider,
        (previous, next) {
          if (next.tabIndex == 1 && scrollController.hasClients) {
            unawaited(
              scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              ),
            );
          }
        },
      );
      return cancel.close;
    }, [scrollController]);

    final groups = ref.watch(genericGroupsProvider);
    final currentQuery = debouncedQuery.value;
    final searchResults = ref.watch(searchResultsProvider(currentQuery));
    final hasSearchText = currentQuery.isNotEmpty;
    final isSearching = hasSearchText;
    final initStepAsync = ref.watch(initializationStepProvider);
    const sidebarLetters = [
      '#',
      'A',
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'H',
      'J',
      'K',
      'L',
      'M',
      'N',
      'P',
      'R',
      'S',
      'T',
      'U',
      'V',
      'W',
      'X',
      'Y',
      'Z',
    ];

    final groupedContent = ref.watch(groupedExplorerContentProvider);
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
        body: Stack(
          children: [
            CustomScrollView(
              key: const PageStorageKey('explorer_list'),
              controller: scrollController,
              slivers: [
                ExplorerContentList(
                  groups: groups,
                  groupedItems: groupedData.groupedItems,
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
            if (!hasSearchText &&
                !groups.isLoading &&
                groupedData.groupedItems.isNotEmpty)
              Positioned(
                top: 0,
                bottom: AppDimens.searchBarHeaderHeight + bottomSpace,
                right: 0,
                child: AlphabetSidebar(
                  onLetterChanged: (letter) {
                    final letterIndex = groupedData.letterIndex;
                    final index =
                        letterIndex[letter] ??
                        _findClosestIndex(
                          letterIndex,
                          sidebarLetters,
                          letter,
                        );
                    if (index == null || index < 0) return;
                    if (!scrollController.hasClients) return;
                    final position = scrollController.position;
                    if (!position.hasContentDimensions) return;
                    final offset = index * explorerListItemHeight;
                    final target = offset.clamp(
                      position.minScrollExtent,
                      position.maxScrollExtent,
                    );
                    scrollController.jumpTo(target);
                  },
                ),
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

int? _findClosestIndex(
  Map<String, int> letterIndex,
  List<String> orderedLetters,
  String requestedLetter,
) {
  final requestedPosition = orderedLetters.indexOf(requestedLetter);

  if (requestedPosition == -1) {
    if (letterIndex.isEmpty) return null;
    return letterIndex.values.reduce((a, b) => a < b ? a : b);
  }

  for (final letter in orderedLetters.skip(requestedPosition)) {
    final index = letterIndex[letter];
    if (index != null) return index;
  }

  for (final letter
      in orderedLetters.take(requestedPosition).toList().reversed) {
    final index = letterIndex[letter];
    if (index != null) return index;
  }

  return null;
}
