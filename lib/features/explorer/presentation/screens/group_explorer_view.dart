import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/hooks/use_app_header.dart';
import 'package:pharma_scan/core/providers/navigation_provider.dart';

import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/group_explorer_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/group_explorer_state.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/group_detail/generics_section.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/group_detail/group_header.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/medication_detail_sheet.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/princeps_hero_card.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

@RoutePage()
class GroupExplorerView extends HookConsumerWidget {
  const GroupExplorerView({
    @PathParam('groupId') required this.groupId,
    super.key,
  });

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollController = useScrollController();

    useEffect(
      () {
        final notifier = ref.read(canSwipeRootProvider.notifier);
        unawaited(Future.microtask(() => notifier.canSwipe = false));
        return () {
          if (context.mounted) {
            notifier.canSwipe = true;
          }
        };
      },
      [groupId],
    );

    final stateAsync = ref.watch(groupExplorerProvider(groupId));

    return stateAsync.when(
      data: (GroupExplorerState state) {
        final shouldShowRelatedSection = state.related.isNotEmpty;
        final heroMember =
            state.princeps.firstOrNull ?? state.generics.firstOrNull;
        final genericsForList = heroMember != null && !heroMember.isPrinceps
            ? state.generics.skip(1).toList()
            : state.generics;

        useAppHeader(
          title: Hero(
            tag: 'group-$groupId',
            child: Material(
              type: MaterialType.transparency,
              child: Text(
                state.title,
                style: context.typo.h4,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          showBackButton: true,
        );

        if (state.princeps.isEmpty && state.generics.isEmpty) {
          return Column(
            children: [
              Expanded(
                child: StatusView(
                  type: StatusType.error,
                  title: Strings.loadDetailsError,
                  description: Strings.errorLoadingGroups,
                  action: Semantics(
                    button: true,
                    label: Strings.backButtonLabel,
                    hint: Strings.backButtonHint,
                    child: ShadButton.outline(
                      onPressed: () => AutoRouter.of(context).maybePop(),
                      child: const Text(Strings.back),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: GroupHeader(
                state: state,
              ),
            ),
            if (state.princeps.isNotEmpty)
              SliverToBoxAdapter(
                child: PrincepsHeroCard(
                  princeps: state.princeps.first,
                  onViewDetails: () =>
                      _openDetailSheet(context, state.princeps.first),
                ),
              ),
            SliverToBoxAdapter(
              child: GenericsSection(
                generics: genericsForList,
                onViewDetail: (member) => _openDetailSheet(context, member),
              ),
            ),
            if (shouldShowRelatedSection)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spacingMd,
                    vertical: AppDimens.spacingMd,
                  ),
                  child: Text(
                    Strings.relatedGroups,
                    style: context.typo.h4,
                  ),
                ),
              ),
            if (shouldShowRelatedSection)
              ...state.related.map(
                (related) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spacingMd,
                      vertical: AppDimens.spacingXs,
                    ),
                    child: MedicationDetailSheet(
                      item: related,
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: Gap(AppDimens.spacingLg)),
          ],
        );
      },
      loading: () {
        useAppHeader(
          title: const Text(Strings.loading),
          showBackButton: true,
        );
        return const Center(child: StatusView(type: StatusType.loading));
      },
      error: (error, stackTrace) {
        useAppHeader(
          title: const Text(Strings.loadDetailsError),
          showBackButton: true,
        );
        return Center(
          child: StatusView(
            type: StatusType.error,
            title: Strings.loadDetailsError,
            description: error.toString(),
            action: Semantics(
              button: true,
              label: Strings.retryButtonLabel,
              hint: Strings.retryButtonHint,
              child: ShadButton(
                onPressed: () => ref.invalidate(groupExplorerProvider(groupId)),
                child: const Text(Strings.retry),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDetailSheet(
    BuildContext context,
    GroupDetailEntity member,
  ) {
    return showShadSheet<void>(
      context: context,
      side: ShadSheetSide.bottom,
      builder: (overlayContext) => MedicationDetailSheet(item: member),
    );
  }
}
