import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/presentation/hooks/use_debounced_controller.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/utils/test_tags.dart';
import 'package:pharma_scan/core/widgets/testable.dart';
import 'package:pharma_scan/features/explorer/domain/models/explorer_enums.dart';
import 'package:pharma_scan/features/explorer/domain/models/search_filters_model.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/search_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/filters/administration_route_filter_tile.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ExplorerSearchBar extends HookConsumerWidget {
  const ExplorerSearchBar({required this.onSearchChanged, super.key});

  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = useDebouncedController();
    final searchFocusNode = useFocusNode();
    final onSearchChangedRef = useRef(onSearchChanged);

    useEffect(() {
      onSearchChangedRef.value = onSearchChanged;
      return null;
    }, [onSearchChanged]);

    useListenable(search.debouncedText);
    useEffect(() {
      void handleDebounced() {
        final trimmed = search.debouncedText.value.trim();
        onSearchChangedRef.value(trimmed);
      }

      handleDebounced();
      search.debouncedText.addListener(handleDebounced);
      return () => search.debouncedText.removeListener(handleDebounced);
    }, [search.debouncedText]);

    final debouncedQuery = search.debouncedText.value;

    final isFetching = ref
        .watch(searchResultsProvider(debouncedQuery))
        .isLoading;

    return Container(
      decoration: BoxDecoration(
        color: context.background,
        border: Border(
          top: BorderSide(color: context.shadColors.border),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spacingMd,
        AppDimens.spacingXs,
        AppDimens.spacingMd,
        AppDimens.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSearchInput(
                  context,
                  ref,
                  search,
                  searchFocusNode,
                  isFetching,
                  onSearchChangedRef,
                ),
              ),
              const Gap(AppDimens.spacingXs),
              _buildFiltersButton(context, ref),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchInput(
    BuildContext context,
    WidgetRef ref,
    ({TextEditingController controller, ValueNotifier<String> debouncedText})
    search,
    FocusNode focusNode,
    bool isFetching,
    ObjectRef<ValueChanged<String>> onSearchChangedRef,
  ) {
    return Testable(
      id: TestTags.searchInput,
      child: Semantics(
        textField: true,
        label: Strings.searchLabel,
        hint: Strings.searchHint,
        value: search.controller.text,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppDimens.inputFieldHeight,
          ),
          child: ShadInput(
            focusNode: focusNode,
            controller: search.controller,
            placeholder: const Text(Strings.searchPlaceholder),
            textInputAction: TextInputAction.search,
            leading: Icon(
              LucideIcons.search,
              size: AppDimens.iconSm,
              color: context.shadColors.mutedForeground,
            ),
            trailing: isFetching
                ? Semantics(
                    label: Strings.searchingInProgress,
                    liveRegion: true,
                    child: const SizedBox(
                      width: AppDimens.iconSm,
                      height: AppDimens.iconSm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (search.controller.text.isNotEmpty && !isFetching
                      ? ShadButton.ghost(
                          size: ShadButtonSize.sm,
                          onPressed: () {
                            search.controller.clear();
                            _commitSearchQuery(
                              '',
                              search,
                              onSearchChangedRef,
                            );
                          },
                          child: const Icon(LucideIcons.x, size: 16),
                        )
                      : null),
            onSubmitted: (_) => _commitSearchQuery(
              search.controller.text,
              search,
              onSearchChangedRef,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersButton(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(searchFiltersProvider);
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
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ShadIconButton.ghost(
              icon: const Icon(LucideIcons.slidersHorizontal),
              onPressed: () => _openFiltersSheet(context, filters, ref),
            ),
            if (hasActiveFilters)
              Positioned(
                top: -2,
                right: -2,
                child: IgnorePointer(
                  child: Semantics(
                    label: Strings.activeFilterCount(filterCount),
                    child: ShadBadge(
                      child: Text(
                        '$filterCount',
                        style: context.shadTextTheme.small,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _commitSearchQuery(
    String rawValue,
    ({TextEditingController controller, ValueNotifier<String> debouncedText})
    search,
    ObjectRef<ValueChanged<String>> onSearchChangedRef,
  ) {
    final trimmed = rawValue.trim();
    search.debouncedText.value = trimmed;
    onSearchChangedRef.value(trimmed);
  }

  Future<void> _openFiltersSheet(
    BuildContext context,
    SearchFilters currentFilters,
    WidgetRef ref,
  ) {
    return showShadSheet(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (overlayContext) => _buildFiltersPanel(
        overlayContext,
        currentFilters,
        ref,
      ),
    );
  }

  Widget _buildFiltersPanel(
    BuildContext context,
    SearchFilters currentFilters,
    WidgetRef ref,
  ) {
    final theme = context.shadTheme;
    return ShadSheet(
      title: const Text(Strings.filters),
      actions: [
        ShadButton.ghost(
          onPressed: currentFilters.hasActiveFilters
              ? ref.read(searchFiltersProvider.notifier).clearFilters
              : null,
          child: const Text(Strings.resetFilters),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            buildAdministrationRouteFilterTile(
              context,
              ref,
              currentFilters,
            ),
            ShadSeparator.horizontal(
              thickness: 1,
              color: theme.colorScheme.border,
            ),
            _buildTherapeuticClassFilter(context, currentFilters, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildTherapeuticClassFilter(
    BuildContext context,
    SearchFilters currentFilters,
    WidgetRef ref,
  ) {
    final theme = context.shadTheme;
    final selectedValue = currentFilters.atcClass;
    final selectedText = selectedValue?.label ?? Strings.allClasses;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spacingMd,
        vertical: AppDimens.spacingSm,
      ),
      child: ShadSelect<AtcLevel1?>(
        initialValue: selectedValue,
        maxHeight: 320,
        options: [
          const ShadOption<AtcLevel1?>(
            value: null,
            child: Text(Strings.allClasses),
          ),
          ...AtcLevel1.values.map(
            (atcClass) => ShadOption<AtcLevel1?>(
              value: atcClass,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(atcClass.label),
                  Text(
                    atcClass.code,
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        selectedOptionBuilder: (context, value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              Strings.therapeuticClassFilter,
              style: theme.textTheme.p,
            ),
            const Gap(4),
            Text(
              selectedText,
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.mutedForeground,
              ),
            ),
          ],
        ),
        onChanged: (value) {
          ref.read(searchFiltersProvider.notifier).filters = currentFilters
              .copyWith(atcClass: value);
          unawaited(Navigator.of(context).maybePop());
        },
      ),
    );
  }
}
