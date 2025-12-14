import 'dart:async';
import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/domain/entities/medicament_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/generic_group_entity.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_result_item_model.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/generic_groups_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/medicament_tile.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/molecule_group_tile.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const double explorerListItemHeight = 108;

class ExplorerContentListSliver extends ConsumerStatefulWidget {
  const ExplorerContentListSliver({
    required this.groups,
    required this.groupedItems,
    required this.searchResults,
    required this.hasSearchText,
    required this.isSearching,
    required this.currentQuery,
    this.bottomPadding = 0,
    super.key,
  });

  final AsyncValue<GenericGroupsState> groups;
  final List<GenericGroupEntity> groupedItems;
  final AsyncValue<List<SearchResultItem>> searchResults;
  final bool hasSearchText;
  final bool isSearching;
  final String currentQuery;
  final double bottomPadding;

  @override
  ConsumerState<ExplorerContentListSliver> createState() => _ExplorerContentListSliverState();
}

class _ExplorerContentListSliverState extends ConsumerState<ExplorerContentListSliver> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedLetter;
  OverlayEntry? _indexHintOverlay;
  final Map<String, int> _letterIndexMap = {};

  @override
  void dispose() {
    _scrollController.dispose();
    _indexHintOverlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shouldShowSearch = widget.hasSearchText && widget.isSearching;
    final content = shouldShowSearch
        ? widget.searchResults.when(
            skipLoadingOnReload: true,
            data: (items) => _buildSearchResultsList(context, ref, items),
            loading: () => _buildSkeletonList(context),
            error: (error, _) =>
                _buildSearchError(context, ref, error, widget.currentQuery),
          )
        : _buildGenericGroupsList(context, ref, widget.groups);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
      child: content,
    );
  }

  Widget _buildGenericGroupsList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<GenericGroupsState> groups,
  ) {
    if (groups.isLoading) {
      return _buildSkeletonList(context);
    }

    final data = groups.asData?.value;
    if (groups.hasError && (data == null || data.items.isEmpty)) {
      return _buildGroupsError(context, ref);
    }
    if (data == null || data.items.isEmpty || widget.groupedItems.isEmpty) {
      return _buildExplorerEmptyState(context);
    }

    final groupedByLetter = _groupItemsByLetter(widget.groupedItems);
    if (groupedByLetter.isEmpty) {
      return _buildExplorerEmptyState(context);
    }

    return Stack(
      children: [
        _buildSliverList(context, groupedByLetter),
        _buildIndexBar(context, groupedByLetter.keys.toList()),
      ],
    );
  }

  Widget _buildSliverList(
    BuildContext context,
    Map<String, List<GenericGroupEntity>> groupedByLetter,
  ) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        ...groupedByLetter.entries.map((entry) {
          final letter = entry.key;
          final items = entry.value;

          return SliverMainAxisGroup(
            slivers: [
              // Letter header
              SliverPersistentHeader(
                pinned: true,
                delegate: _LetterHeaderDelegate(letter: letter),
              ),
              // Items for this letter
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing2xs),
                    child: _buildGenericGroupTile(context, items[index]),
                  ),
                  childCount: items.length,
                ),
              ),
            ],
          );
        }),
        SliverToBoxAdapter(
          child: SizedBox(height: widget.bottomPadding + 80), // Extra space for index bar
        ),
      ],
    );
  }

  Widget _buildIndexBar(BuildContext context, List<String> letters) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: widget.bottomPadding,
      child: Container(
        width: 20,
        alignment: Alignment.center,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: letters.length,
          itemBuilder: (context, index) {
            final letter = letters[index];
            final isSelected = _selectedLetter == letter;

            return GestureDetector(
              onTap: () => _scrollToLetter(letter),
              onTapDown: (_) => _showIndexHint(letter),
              onTapUp: (_) => _hideIndexHint(),
              onTapCancel: _hideIndexHint,
              child: Container(
                height: 20,
                alignment: Alignment.center,
                decoration: isSelected
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.colors.primary.withValues(alpha: 0.1),
                      )
                    : null,
                child: Text(
                  letter,
                  style: context.typo.small.copyWith(
                    color: isSelected ? context.colors.primary : context.colors.mutedForeground,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Map<String, List<GenericGroupEntity>> _groupItemsByLetter(List<GenericGroupEntity> items) {
    final grouped = <String, List<GenericGroupEntity>>{};
    _letterIndexMap.clear();

    // Sort items alphabetically
    final sortedItems = [...items]..sort((a, b) {
      final aPrinciples = a.commonPrincipes.isNotEmpty ? a.commonPrincipes.split(',')[0].trim() : '';
      final bPrinciples = b.commonPrincipes.isNotEmpty ? b.commonPrincipes.split(',')[0].trim() : '';
      return aPrinciples.toUpperCase().compareTo(bPrinciples.toUpperCase());
    });

    int currentIndex = 0;
    for (final item in sortedItems) {
      final principles = item.commonPrincipes.isNotEmpty
          ? item.commonPrincipes.split(',')[0].trim()
          : '';

      if (principles.isEmpty) {
        grouped['#'] ??= [];
        grouped['#']!.add(item);
        if (!_letterIndexMap.containsKey('#')) {
          _letterIndexMap['#'] = currentIndex;
        }
      } else {
        final firstChar = principles[0].toUpperCase();
        final isAlpha = RegExp('[A-ZÀ-ÖØ-Ý]').hasMatch(firstChar);
        final key = isAlpha ? firstChar : '#';

        grouped[key] ??= [];
        grouped[key]!.add(item);

        if (!_letterIndexMap.containsKey(key)) {
          _letterIndexMap[key] = currentIndex;
        }
      }
      currentIndex++;
    }

    // Sort the keys alphabetically
    final sortedKeys = grouped.keys.toList()..sort();
    return {for (final key in sortedKeys) key: grouped[key]!};
  }

  void _scrollToLetter(String letter) {
    final index = _letterIndexMap[letter];
    if (index != null && _scrollController.hasClients) {
      // Calculate scroll position based on item index
      final offset = index * (explorerListItemHeight + AppDimens.spacingXs) + 32; // 32 for header height
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _selectedLetter = letter;
      });

      // Reset selection after animation
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _selectedLetter = null;
          });
        }
      });
    }
  }

  void _showIndexHint(String letter) {
    _hideIndexHint();
    _indexHintOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: (MediaQuery.of(context).size.width - 120) / 2,
        top: (MediaQuery.of(context).size.height - 80) / 2,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colors.border),
            ),
            child: Text(
              letter,
              style: context.typo.h3.copyWith(
                color: context.colors.foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_indexHintOverlay!);
  }

  void _hideIndexHint() {
    _indexHintOverlay?.remove();
    _indexHintOverlay = null;
  }

  Widget _buildGroupsError(BuildContext context, WidgetRef ref) {
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

  Widget _buildExplorerEmptyState(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(
        top: AppDimens.spacingLg,
        bottom: AppDimens.spacingXl,
      ),
      child: StatusView(
        type: StatusType.empty,
        title: Strings.explorerEmptyTitle,
        description: Strings.explorerEmptyDescription,
      ),
    );
  }

  /// Formats principles string for display by capitalizing the first letter.
  /// Example: "PARACETAMOL" -> "Paracetamol", "PARACETAMOL, CODEINE" -> "Paracetamol, Codeine"
  String _formatPrinciples(String principles) {
    if (principles.isEmpty) return principles;
    return principles
        .split(',')
        .map((p) {
          final trimmed = p.trim();
          if (trimmed.isEmpty) return trimmed;
          return trimmed[0].toUpperCase() +
              (trimmed.length > 1 ? trimmed.substring(1).toLowerCase() : '');
        })
        .where((p) => p.isNotEmpty)
        .join(', ');
  }

  Widget _buildGenericGroupTile(
    BuildContext context,
    GenericGroupEntity group,
  ) {
    final hasPrinciples = group.commonPrincipes.isNotEmpty;
    final principles = hasPrinciples
        ? _formatPrinciples(group.commonPrincipes)
        : Strings.notDetermined;
    final brand = group.princepsReferenceName.isNotEmpty
        ? group.princepsReferenceName
        : Strings.notDetermined;
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: '$principles, référence $brand',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => AutoRouter.of(context).push(
            GroupExplorerRoute(groupId: group.groupId.toString()),
          ),
          child: SizedBox(
            height: explorerListItemHeight,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingMd,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: context.colors.border),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: context.colors.border,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      Strings.generics.substring(0, 1),
                      style: context.typo.small,
                    ),
                  ),
                  const Gap(AppDimens.spacingSm),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          principles,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typo.p.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          brand,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.typo.small.copyWith(
                            color: context.colors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(AppDimens.spacingXs),
                  const ExcludeSemantics(
                    child: Icon(LucideIcons.chevronRight, size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonList(BuildContext context) {
    final placeholderColor = context.colors.muted.withValues(
      alpha: 0.3,
    );
    return ListView.separated(
      padding: EdgeInsets.only(
        bottom: widget.bottomPadding,
        top: AppDimens.spacing2xs,
      ),
      itemCount: 4,
      separatorBuilder: (context, index) => const Gap(AppDimens.spacing2xs),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.spacing2xs,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spacingMd,
              vertical: AppDimens.spacingSm,
            ),
            child: Row(
              children: [
                _SkeletonBlock(
                  height: 20,
                  width: 20,
                  color: placeholderColor,
                ),
                const Gap(AppDimens.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SkeletonBlock(
                        height: 16,
                        width: 200,
                        color: placeholderColor,
                      ),
                      const Gap(4),
                      _SkeletonBlock(
                        height: 14,
                        width: 150,
                        color: placeholderColor,
                      ),
                    ],
                  ),
                ),
                const Gap(AppDimens.spacingXs),
                ExcludeSemantics(
                  child: _SkeletonBlock(
                    height: 16,
                    width: 16,
                    color: placeholderColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResultsList(
    BuildContext context,
    WidgetRef ref,
    List<SearchResultItem> results,
  ) {
    if (results.isEmpty) {
      final filters = ref.read(searchFiltersProvider);
      final hasFilters = filters.hasActiveFilters;

      return Padding(
        padding: EdgeInsets.only(
          top: AppDimens.spacing2xl,
          bottom: widget.bottomPadding + AppDimens.spacing2xl,
        ),
        child: StatusView(
          type: StatusType.empty,
          title: Strings.noResults,
          description: hasFilters ? Strings.filters : null,
          actionLabel: hasFilters ? Strings.clearFilters : null,
          onAction: hasFilters
              ? ref.read(searchFiltersProvider.notifier).clearFilters
              : null,
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        bottom: widget.bottomPadding,
        top: AppDimens.spacing2xs,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];

        if (result is ClusterResult) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing2xs),
            child: MoleculeGroupTile(
              moleculeName: result.displayName,
              princepsName: result.sortKey.isNotEmpty
                  ? result.sortKey
                  : (result.displayName.isNotEmpty
                        ? result.displayName
                        : Strings.notDetermined),
              groups: result.groups,
              itemBuilder: _buildGenericGroupTile,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.spacing2xs),
          child: MedicamentTile(
            item: result,
            currentQuery: widget.currentQuery,
            onTap: () => _handleSearchResultTap(context, result),
          ),
        );
      },
    );
  }

  Widget _buildSearchError(
    BuildContext context,
    WidgetRef ref,
    Object error,
    String currentQuery,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
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

  void _handleSearchResultTap(BuildContext context, SearchResultItem result) {
    switch (result) {
      case ClusterResult():
        break;
      case GroupResult(group: final group):
        unawaited(
          AutoRouter.of(context).push(
            GroupExplorerRoute(groupId: group.groupId.toString()),
          ),
        );
      case PrincepsResult(groupId: final groupId):
        unawaited(
          AutoRouter.of(context).push(
            GroupExplorerRoute(groupId: groupId.toString()),
          ),
        );
      case GenericResult(groupId: final groupId):
        unawaited(
          AutoRouter.of(context).push(
            GroupExplorerRoute(groupId: groupId.toString()),
          ),
        );
      case StandaloneResult(
        summary: final summary,
        representativeCip: final representativeCip,
      ):
        unawaited(
          showShadSheet<void>(
            context: context,
            side: ShadSheetSide.bottom,
            builder: (overlayContext) => _buildStandaloneDetailOverlay(
              overlayContext,
              summary,
              representativeCip,
            ),
          ),
        );
    }
  }

  Widget _buildStandaloneDetailOverlay(
    BuildContext context,
    MedicamentEntity summary,
    String representativeCip,
  ) {
    final heroTag = 'standalone-$representativeCip';
    // Principles are already normalized from the database
    final sanitizedPrinciples = summary.dbData.principesActifsCommuns;

    Future<void> copyToClipboard(String text, String label) async {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ShadToaster.of(context).show(
          ShadToast(
            title: const Text(Strings.copiedToClipboard),
            description: Text(label),
          ),
        );
      }
    }

    Widget buildDetailItem(
      BuildContext context, {
      required String label,
      required String value,
      bool copyable = false,
      String? copyLabel,
      VoidCallback? onCopy,
    }) {
      final theme = context.shadTheme;
      final mutedForeground = theme.colorScheme.mutedForeground;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.small.copyWith(color: mutedForeground),
          ),
          const Gap(AppDimens.spacing2xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: theme.textTheme.p,
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (copyable && onCopy != null) ...[
                const Gap(AppDimens.spacingXs),
                Semantics(
                  button: true,
                  label: copyLabel ?? Strings.copyToClipboard,
                  hint: Strings.copyToClipboard,
                  child: ShadIconButton.ghost(
                    icon: const Icon(LucideIcons.copy, size: 16),
                    onPressed: onCopy,
                  ),
                ),
              ],
            ],
          ),
        ],
      );
    }

    return ShadSheet(
      title: const Text(Strings.medicationDetails),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: heroTag,
                child: Material(
                  type: MaterialType.transparency,
                  child: buildDetailItem(
                    context,
                    label: Strings.nameLabel,
                    value: summary.dbData.nomCanonique,
                    copyable: true,
                    copyLabel: Strings.copyNameLabel,
                    onCopy: () => copyToClipboard(
                      summary.dbData.nomCanonique,
                      Strings.copyNameLabel,
                    ),
                  ),
                ),
              ),
              const Gap(AppDimens.spacingMd),
              buildDetailItem(
                context,
                label: Strings.activePrinciplesLabel,
                value: (sanitizedPrinciples?.isNotEmpty ?? false)
                    ? _parseAndJoinPrinciplesFromJson(sanitizedPrinciples!)
                    : Strings.notDetermined,
              ),
              const Gap(AppDimens.spacingMd),
              buildDetailItem(
                context,
                label: Strings.cip,
                value: representativeCip,
                copyable: true,
                copyLabel: Strings.copyCipLabel,
                onCopy: () => copyToClipboard(
                  representativeCip,
                  Strings.copyCipLabel,
                ),
              ),
              if (summary.titulaire != null &&
                  summary.titulaire!.isNotEmpty) ...[
                const Gap(AppDimens.spacingMd),
                buildDetailItem(
                  context,
                  label: Strings.holder,
                  value: summary.titulaire!,
                ),
              ],
              if (summary.formePharmaceutique.isNotEmpty) ...[
                const Gap(AppDimens.spacingMd),
                buildDetailItem(
                  context,
                  label: Strings.pharmaceuticalFormLabel,
                  value: summary.formePharmaceutique,
                ),
              ],
              const Gap(AppDimens.spacingMd),
              ShadBadge.outline(
                child: Text(
                  Strings.uniqueMedicationNoGroup,
                  style: context.typo.small,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _parseAndJoinPrinciplesFromJson(String jsonStr) {
    try {
      final decoded = json.decode(jsonStr);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).join(', ');
      }
    } on FormatException {
      // If parsing fails, return the original string
      return jsonStr;
    }
    // If it's not a list, return as is
    return jsonStr;
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
        borderRadius: context.shadTheme.radius,
      ),
    );
  }
}

class _LetterHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _LetterHeaderDelegate({required this.letter});

  final String letter;

  @override
  double get minExtent => 32;

  @override
  double get maxExtent => 32;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
      decoration: BoxDecoration(
        color: context.colors.muted,
        border: Border(
          bottom: BorderSide(color: context.colors.border),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        letter,
        style: context.typo.small.copyWith(
          color: context.colors.mutedForeground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_LetterHeaderDelegate oldDelegate) {
    return oldDelegate.letter != letter;
  }
}