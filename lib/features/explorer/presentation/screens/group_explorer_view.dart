import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/providers/navigation_provider.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/scroll_to_top_fab.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/view_group_detail_extensions.dart';
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

    useEffect(() {
      final notifier = ref.read(canSwipeRootProvider.notifier);
      unawaited(Future.microtask(() => notifier.canSwipe = false));
      return () {
        if (context.mounted) {
          notifier.canSwipe = true;
        }
      };
    }, [groupId]);

    final stateAsync = ref.watch(groupExplorerProvider(groupId));

    return stateAsync.when(
      data: (GroupExplorerState state) {
        if (state.princeps.isEmpty && state.generics.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(Strings.loadDetailsError),
              leading: ShadIconButton.ghost(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => AutoRouter.of(context).maybePop(),
              ),
            ),
            body: StatusView(
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
          );
        }

        final shouldShowRelatedSection = state.related.isNotEmpty;

        // Detect if we're in Scanner context
        final isInScannerContext = _isInScannerContext(context);
        final heroMember =
            state.princeps.firstOrNull ?? state.generics.firstOrNull;
        final genericsForList = heroMember != null && !heroMember.isPrinceps
            ? state.generics.skip(1).toList()
            : state.generics;

        return Scaffold(
          appBar: AppBar(
            title: Hero(
              tag: 'group-$groupId',
              child: Material(
                type: MaterialType.transparency,
                child: Text(
                  state.title,
                  style: context.shadTextTheme.h4,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            leading: ShadIconButton.ghost(
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => AutoRouter.of(context).maybePop(),
            ),
            actions: isInScannerContext
                ? [
                    Tooltip(
                      message: Strings.viewInExplorer,
                      child: ShadIconButton.ghost(
                        icon: const Icon(LucideIcons.database),
                        onPressed: () => _navigateToExplorer(context, groupId),
                      ),
                    ),
                  ]
                : null,
          ),
          body: Stack(
            children: [
              CustomScrollView(
                controller: scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: GroupHeader(state: state),
                  ),
                  if (heroMember != null)
                    SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _buildSectionHeader(
                            context: context,
                            title: Strings.princeps,
                            badgeCount: state.princeps.length,
                            icon: LucideIcons.shieldCheck,
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spacingMd,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: PrincepsHeroCard(
                              princeps: heroMember,
                              isFallbackGeneric: !heroMember.isPrinceps,
                              onViewDetails: () => _openDetailSheet(
                                context,
                                heroMember,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (genericsForList.isNotEmpty)
                    SliverToBoxAdapter(
                      child: GenericsSection(
                        generics: genericsForList,
                        onViewDetail: (generic) =>
                            _openDetailSheet(context, generic),
                      ),
                    ),
                  if (shouldShowRelatedSection)
                    _buildRelatedSectionSliver(
                      context,
                      state.related,
                      isLoading: false,
                    ),
                  const SliverGap(AppDimens.spacingXl),
                ],
              ),
              Positioned(
                right: AppDimens.spacingMd,
                bottom:
                    AppDimens.spacingMd + MediaQuery.paddingOf(context).bottom,
                child: ScrollToTopFab(controller: scrollController),
              ),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text(Strings.loading),
          leading: ShadIconButton.ghost(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => AutoRouter.of(context).maybePop(),
          ),
        ),
        body: const StatusView(type: StatusType.loading),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(
          title: const Text(Strings.loadDetailsError),
          leading: ShadIconButton.ghost(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => AutoRouter.of(context).maybePop(),
          ),
        ),
        body: StatusView(
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
      ),
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

  Widget _buildRelatedSectionSliver(
    BuildContext context,
    List<GroupDetailEntity> relatedMembers, {
    required bool isLoading,
  }) {
    if (isLoading && relatedMembers.isEmpty) {
      return SliverMainAxisGroup(
        slivers: [
          _buildStickySectionHeader(
            context: context,
            title: Strings.relatedTherapies,
            icon: LucideIcons.link,
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppDimens.spacingMd),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (relatedMembers.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        _buildStickySectionHeader(
          context: context,
          title: Strings.relatedTherapies,
          badgeCount: relatedMembers.length,
          icon: LucideIcons.link,
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final therapy = relatedMembers[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimens.spacing2xs,
                ),
                child: Semantics(
                  button: true,
                  label: Strings.associatedTherapySemantics(
                    therapy.displayName,
                  ),
                  child: _buildMemberTile(
                    context,
                    therapy,
                    showNavigationIndicator: true,
                    navigationGroupId: therapy.groupId,
                  ),
                ),
              );
            }, childCount: relatedMembers.length),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberTile(
    BuildContext context,
    GroupDetailEntity member, {
    required bool showNavigationIndicator,
    String? navigationGroupId,
  }) {
    return MedicationListTile(
      item: member,
      onTap: showNavigationIndicator && navigationGroupId != null
          ? () => AutoRouter.of(context).push(
              GroupExplorerRoute(groupId: navigationGroupId),
            )
          : null,
      showNavigationIndicator:
          showNavigationIndicator && navigationGroupId != null,
    );
  }

  bool _isInScannerContext(BuildContext context) {
    final parentRoute = AutoRouter.of(context).parent();
    return parentRoute?.routeData.name == 'ScannerTabRoute';
  }

  void _navigateToExplorer(BuildContext context, String groupId) {
    unawaited(
      AutoRouter.of(context).navigate(const ExplorerTabRoute()).then((_) {
        if (context.mounted) {
          unawaited(
            AutoRouter.of(context).push(GroupExplorerRoute(groupId: groupId)),
          );
        }
      }),
    );
  }
}

const EdgeInsets _sectionHeaderPadding = EdgeInsets.fromLTRB(
  AppDimens.spacingMd,
  AppDimens.spacingXl,
  AppDimens.spacingMd,
  AppDimens.spacingXs,
);

Widget _buildSectionHeader({
  required BuildContext context,
  required String title,
  int? badgeCount,
  IconData? icon,
  EdgeInsetsGeometry padding = _sectionHeaderPadding,
}) {
  final theme = context.shadTheme;
  final iconColor = theme.colorScheme.mutedForeground;

  return Padding(
    padding: padding,
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: AppDimens.iconSm, color: iconColor),
          const Gap(AppDimens.spacingXs),
        ],
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.h4,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (badgeCount != null) ...[
          const Gap(AppDimens.spacingXs),
          ShadBadge(child: Text('$badgeCount', style: theme.textTheme.small)),
        ],
      ],
    ),
  );
}

SliverPersistentHeader _buildStickySectionHeader({
  required BuildContext context,
  required String title,
  int? badgeCount,
  IconData? icon,
  EdgeInsetsGeometry? padding,
  TextScaler? textScaler,
  double? height,
}) {
  final effectivePadding = padding ?? _sectionHeaderPadding;
  final effectiveTextScaler = textScaler ?? MediaQuery.textScalerOf(context);

  return SliverPersistentHeader(
    pinned: true,
    delegate: _SectionHeaderDelegate(
      title: title,
      badgeCount: badgeCount,
      icon: icon,
      padding: effectivePadding,
      textScaler: effectiveTextScaler,
      height: height,
    ),
  );
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _SectionHeaderDelegate({
    required this.title,
    required this.padding,
    required this.textScaler,
    this.badgeCount,
    this.icon,
    this.height,
  });

  final String title;
  final int? badgeCount;
  final IconData? icon;
  final EdgeInsetsGeometry padding;
  final TextScaler textScaler;
  final double? height;

  @override
  double get minExtent => _calculateHeight();

  @override
  double get maxExtent => _calculateHeight();

  double _calculateHeight() {
    if (height != null) {
      return height!;
    }

    final paddingResolved = padding.resolve(TextDirection.ltr);
    final paddingVertical = paddingResolved.top + paddingResolved.bottom;

    const h4FontSize = 20.0;
    const h4HeightMultiplier = 1.4;
    const baseTextHeight = h4FontSize * h4HeightMultiplier;

    final baseHeight = paddingVertical + baseTextHeight;

    return textScaler.scale(baseHeight).clamp(baseHeight, baseHeight * 2.0);
  }

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return _buildSectionHeader(
      context: context,
      title: title,
      badgeCount: badgeCount,
      icon: icon,
      padding: padding,
    );
  }

  @override
  bool shouldRebuild(_SectionHeaderDelegate oldDelegate) {
    return title != oldDelegate.title ||
        badgeCount != oldDelegate.badgeCount ||
        icon != oldDelegate.icon ||
        padding != oldDelegate.padding ||
        height != oldDelegate.height ||
        textScaler != oldDelegate.textScaler;
  }
}
