import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/config/data_sources.dart';
import 'package:pharma_scan/core/providers/navigation_provider.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/formatters.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/scroll_to_top_fab.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_badges.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/domain/entities/group_detail_entity.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/view_group_detail_extensions.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/group_explorer_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/group_explorer_state.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/medication_detail_sheet.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/princeps_hero_card.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final filterController = useTextEditingController();
    useListenable(filterController);

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
        final filterQuery = filterController.text.trim().toLowerCase();
        final filteredGenerics = filterQuery.isEmpty
            ? genericsForList
            : genericsForList.where((generic) {
                final name = generic.displayName.toLowerCase();
                final lab = generic.parsedTitulaire.toLowerCase();
                return name.contains(filterQuery) || lab.contains(filterQuery);
              }).toList();

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
                    child: Column(
                      children: [
                        _buildAppBarContent(
                          context,
                          state,
                        ),
                      ],
                    ),
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
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spacingMd,
                        ),
                        child: ShadAccordion<String>.multiple(
                          initialValue: const <String>[],
                          children: [
                            ShadAccordionItem(
                              value: 'generics',
                              title: Row(
                                children: [
                                  Icon(
                                    LucideIcons.copy,
                                    size: AppDimens.iconSm,
                                    color: context.shadColors.mutedForeground,
                                  ),
                                  const Gap(AppDimens.spacingXs),
                                  Expanded(
                                    child: Text(
                                      Strings.generics,
                                      style: context.shadTextTheme.h4,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Gap(AppDimens.spacingXs),
                                  ShadBadge(
                                    child: Text(
                                      '${filteredGenerics.length}',
                                      style: context.shadTextTheme.small,
                                    ),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppDimens.spacingSm,
                                    ),
                                    child: ShadInput(
                                      controller: filterController,
                                      placeholder: const Text(
                                        'Filtrer (ex: Biogaran, Teva...)',
                                      ),
                                      leading: Icon(
                                        LucideIcons.search,
                                        size: AppDimens.iconSm,
                                        color:
                                            context.shadColors.mutedForeground,
                                      ),
                                      trailing: filterController.text.isNotEmpty
                                          ? ShadButton.ghost(
                                              size: ShadButtonSize.sm,
                                              onPressed: filterController.clear,
                                              child: const Icon(
                                                LucideIcons.x,
                                                size: AppDimens.iconSm,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                  ...List.generate(filteredGenerics.length, (
                                    index,
                                  ) {
                                    final generic = filteredGenerics[index];
                                    return _CompactGenericTile(
                                      item: generic,
                                      onTap: () => _openDetailSheet(
                                        context,
                                        generic,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildAppBarContent(
    BuildContext context,
    GroupExplorerState state,
  ) {
    final theme = context.shadTheme;
    final metadataBadges = <Widget>[
      if (state.distinctForms.isNotEmpty)
        ...state.distinctForms.map(
          (form) => ShadBadge.secondary(
            child: Text(
              Strings.formWithValue(form),
              style: theme.textTheme.small,
            ),
          ),
        ),
    ];
    final conditionBadges = state.aggregatedConditions
        .map((condition) => condition.trim())
        .where((condition) => condition.isNotEmpty)
        .map(
          (condition) => ShadBadge.outline(
            child: Text(
              condition,
              style: theme.textTheme.small,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList();
    final priceLabel = state.priceLabel;
    final refundValue = state.refundLabel;

    // Get regulatory flags from first princeps
    final firstPrinceps = state.princeps.firstOrNull;
    final regulatoryBadgesWidget = firstPrinceps != null
        ? RegulatoryBadges(
            isNarcotic: firstPrinceps.isNarcotic,
            isList1: firstPrinceps.isList1,
            isList2: firstPrinceps.isList2,
            isException: firstPrinceps.isException,
            isRestricted: firstPrinceps.isRestricted,
            isHospitalOnly: firstPrinceps.isHospitalOnly,
            isDental: firstPrinceps.isDental,
            isSurveillance: firstPrinceps.isSurveillance,
            isOtc: firstPrinceps.isOtc,
          )
        : null;

    final allBadges = <Widget>[
      ?regulatoryBadgesWidget,
      ...metadataBadges,
      ...conditionBadges,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spacingMd,
        AppDimens.spacingSm,
        AppDimens.spacingMd,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.commonPrincipes.isNotEmpty) ...[
            Text(
              state.commonPrincipes.join(', '),
              style: theme.textTheme.h4.copyWith(
                color: theme.colorScheme.foreground,
              ),
            ),
            const Gap(AppDimens.spacing2xs),
          ],
          Text(
            state.title,
            style: theme.textTheme.p.copyWith(
              color: theme.colorScheme.mutedForeground,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Gap(AppDimens.spacing2xs),
          ShadBadge.outline(
            child: Text(
              Strings.summaryLine(state.princeps.length, state.generics.length),
              style: theme.textTheme.small,
            ),
          ),
          if (allBadges.isNotEmpty) ...[
            const Gap(AppDimens.spacingSm),
            Wrap(
              spacing: AppDimens.spacing2xs,
              runSpacing: AppDimens.spacing2xs,
              children: allBadges,
            ),
          ],
          const Gap(AppDimens.spacingSm),
          _buildMetadataTiles(context, priceLabel, refundValue),
          _buildActionBar(context, state),
          if ((state.rawLabelAnsm?.isNotEmpty ?? false) ||
              (state.parsingMethod?.isNotEmpty ?? false) ||
              (state.princepsCisReference?.isNotEmpty ?? false)) ...[
            const Gap(AppDimens.spacingSm),
            _buildTechnicalInfo(context, state),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataTiles(
    BuildContext context,
    String priceLabel,
    String refundValue,
  ) {
    return ShadCard(
      padding: const EdgeInsets.symmetric(
        vertical: AppDimens.spacingSm,
        horizontal: AppDimens.spacingMd,
      ),
      child: Row(
        children: [
          Expanded(
            child: _MetadataItem(
              icon: LucideIcons.banknote,
              label: Strings.priceShort,
              value: priceLabel,
            ),
          ),
          const Gap(AppDimens.spacingMd),
          Expanded(
            child: _MetadataItem(
              icon: LucideIcons.percent,
              label: Strings.refundShort,
              value: refundValue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalInfo(
    BuildContext context,
    GroupExplorerState state,
  ) {
    final theme = context.shadTheme;
    final badge = state.parsingMethod != null
        ? _buildParsingMethodBadge(theme, state.parsingMethod!)
        : null;

    return ShadAccordion<String>.multiple(
      children: [
        ShadAccordionItem(
          value: 'technical-info',
          title: Text(
            Strings.technicalInformation,
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.border),
              borderRadius: theme.radius,
            ),
            padding: const EdgeInsets.symmetric(
              vertical: AppDimens.spacingSm,
              horizontal: AppDimens.spacingMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (badge != null) ...[
                  Align(alignment: Alignment.centerRight, child: badge),
                  const Gap(AppDimens.spacing2xs),
                ],
                if (state.rawLabelAnsm?.isNotEmpty ?? false) ...[
                  Text(
                    Strings.rawLabelAnsm,
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    state.rawLabelAnsm!,
                    style: theme.textTheme.p,
                  ),
                  const Gap(AppDimens.spacing2xs),
                ],
                if (state.princepsCisReference?.isNotEmpty ?? false) ...[
                  Text(
                    Strings.princepsCisReference,
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                  const Gap(2),
                  Text(
                    state.princepsCisReference!,
                    style: theme.textTheme.p,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  ShadBadge _buildParsingMethodBadge(
    ShadThemeData theme,
    String method,
  ) {
    final label = _parsingMethodLabel(method);
    switch (method) {
      case 'relational':
        return ShadBadge(
          child: Text(label, style: theme.textTheme.small),
        );
      case 'text_split':
        return ShadBadge.outline(
          child: Text(label, style: theme.textTheme.small),
        );
      case 'text_smart_split':
      case 'fallback':
      default:
        return ShadBadge.secondary(
          child: Text(
            label,
            style: theme.textTheme.small,
          ),
        );
    }
  }

  String _parsingMethodLabel(String method) {
    switch (method) {
      case 'relational':
        return Strings.parsingMethodRelational;
      case 'text_split':
        return Strings.parsingMethodTextSplit;
      case 'text_smart_split':
        return Strings.parsingMethodSmartSplit;
      case 'fallback':
      default:
        return Strings.parsingMethodFallback;
    }
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
    return _MedicationListTile(
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

  Widget _buildActionBar(
    BuildContext context,
    GroupExplorerState state,
  ) {
    final cisCode = state.princepsCisCode;
    final ansmUrl = state.ansmAlertUrl;

    if (cisCode == null || cisCode.isEmpty) {
      return const SizedBox.shrink();
    }

    final ficheUrl = DataSources.ficheAnsm(cisCode);
    final rcpUrl = DataSources.rcpAnsm(cisCode);

    return Padding(
      padding: const EdgeInsets.only(top: AppDimens.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ansmUrl != null && ansmUrl.isNotEmpty) ...[
            ShadButton.destructive(
              width: double.infinity,
              onPressed: () => _launchUrl(context, ansmUrl),
              leading: const Icon(
                LucideIcons.triangleAlert,
                size: AppDimens.iconSm,
              ),
              child: const Text(Strings.shortageAlert),
            ),
            const Gap(AppDimens.spacingSm),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              final ficheButton = ShadButton.secondary(
                width: double.infinity,
                onPressed: () => _launchUrl(context, ficheUrl),
                leading: Icon(
                  LucideIcons.info,
                  size: AppDimens.iconSm,
                  color: context.shadColors.secondaryForeground,
                ),
                child: const Text(Strings.ficheInfo),
              );

              final rcpButton = ShadButton.outline(
                width: double.infinity,
                onPressed: () => _launchUrl(context, rcpUrl),
                leading: Icon(
                  LucideIcons.fileText,
                  size: AppDimens.iconSm,
                  color: context.shadColors.foreground,
                ),
                child: const Text(Strings.rcpDocument),
              );

              if (!isNarrow) {
                return Row(
                  children: [
                    Expanded(child: ficheButton),
                    const Gap(AppDimens.spacingSm),
                    Expanded(child: rcpButton),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ficheButton,
                  const Gap(AppDimens.spacingSm),
                  rcpButton,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri);
    } on Exception catch (e) {
      if (context.mounted) {
        ShadToaster.of(context).show(
          ShadToast.destructive(
            title: const Text(Strings.error),
            description: Text('${Strings.unableToOpenUrl}: $url'),
          ),
        );
      }
      LoggerService.error('Failed to launch URL: $url', e);
    }
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

class _MetadataItem extends StatelessWidget {
  const _MetadataItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.shadTextTheme;
    final muted = textTheme.muted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: context.shadColors.mutedForeground,
        ),
        const Gap(AppDimens.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: muted),
              Text(
                value,
                style: textTheme.small,
              ),
            ],
          ),
        ),
      ],
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

class _CompactGenericTile extends StatelessWidget {
  const _CompactGenericTile({
    required this.item,
    required this.onTap,
  });

  final GroupDetailEntity item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _MedicationListTile(
      item: item,
      onTap: onTap,
      showNavigationIndicator: false,
    );
  }
}

class _MedicationListTile extends StatelessWidget {
  const _MedicationListTile({
    required this.item,
    required this.onTap,
    required this.showNavigationIndicator,
  });

  final GroupDetailEntity item;
  final VoidCallback? onTap;
  final bool showNavigationIndicator;

  @override
  Widget build(BuildContext context) {
    final theme = context.shadTheme;
    final name = item.displayName;
    final cipText = item.codeCip.isNotEmpty
        ? '${Strings.cip} ${item.codeCip}'
        : '';
    final lab = item.parsedTitulaire.isEmpty
        ? Strings.unknownHolder
        : item.parsedTitulaire;
    final subtitle = [
      cipText,
      lab,
    ].where((value) => value.isNotEmpty).join(' • ');

    final priceText = item.prixPublic != null
        ? formatEuro(item.prixPublic!)
        : null;
    final refundText = item.trimmedRefundRate;

    final statusBadge = item.isList1
        ? Strings.badgeList1
        : item.isList2
        ? Strings.badgeList2
        : item.isHospitalOnly
        ? Strings.hospitalBadge
        : null;
    final stockBadge = item.trimmedAvailabilityStatus != null
        ? Strings.stockAlert(item.trimmedAvailabilityStatus!)
        : null;

    final details = [priceText, refundText].whereType<String>().join(' • ');

    return Semantics(
      button: onTap != null,
      label: _medicationSemanticsLabel(
        item,
        subtitle.isEmpty ? null : subtitle,
        details.isEmpty ? null : details,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth =
              constraints.hasBoundedWidth && constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;

          return SizedBox(
            width: itemWidth,
            child: InkWell(
              onTap: onTap,
              child: Container(
                width: itemWidth,
                constraints: const BoxConstraints(minHeight: 72),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spacingMd,
                  vertical: AppDimens.spacingSm,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: theme.colorScheme.border),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.scale(
                      scale: 0.9,
                      child: ProductTypeBadge(memberType: item.memberType),
                    ),
                    const Gap(AppDimens.spacingSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            textAlign: TextAlign.start,
                            style: theme.textTheme.p.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Gap(4),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.small.copyWith(
                                color: theme.colorScheme.mutedForeground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const Gap(AppDimens.spacing2xs),
                          Row(
                            children: [
                              if (priceText != null) ...[
                                ShadBadge(
                                  child: Text(
                                    priceText,
                                    style: theme.textTheme.small,
                                  ),
                                ),
                                const Gap(AppDimens.spacing2xs),
                              ],
                              if (refundText != null) ...[
                                ShadBadge.outline(
                                  child: Text(
                                    refundText,
                                    style: theme.textTheme.small,
                                  ),
                                ),
                                const Gap(AppDimens.spacing2xs),
                              ],
                              if (priceText == null && refundText == null)
                                Text(
                                  Strings.refundNotAvailable,
                                  style: theme.textTheme.small.copyWith(
                                    color: theme.colorScheme.mutedForeground,
                                  ),
                                ),
                            ],
                          ),
                          if (statusBadge != null ||
                              stockBadge != null ||
                              showNavigationIndicator) ...[
                            const Gap(AppDimens.spacing2xs),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  if (statusBadge != null)
                                    ShadBadge.destructive(
                                      child: Text(
                                        statusBadge,
                                        style: theme.textTheme.small,
                                      ),
                                    ),
                                  if (statusBadge != null &&
                                      (stockBadge != null ||
                                          showNavigationIndicator))
                                    const SizedBox(
                                      width: AppDimens.spacing2xs,
                                    ),
                                  if (stockBadge != null)
                                    ShadBadge.outline(
                                      child: Text(
                                        stockBadge,
                                        style: theme.textTheme.small,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  if (stockBadge != null &&
                                      showNavigationIndicator)
                                    const SizedBox(
                                      width: AppDimens.spacing2xs,
                                    ),
                                  if (showNavigationIndicator)
                                    const Icon(
                                      LucideIcons.chevronRight,
                                      size: 16,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

String _medicationSemanticsLabel(
  GroupDetailEntity member,
  String? subtitle,
  String? details,
) {
  final buffer = StringBuffer(member.displayName);
  if (subtitle != null) {
    buffer.write(', $subtitle');
  }
  if (details != null) {
    buffer.write(', $details');
  }
  if (member.trimmedAvailabilityStatus != null) {
    buffer.write(', ${Strings.stockAlert(member.trimmedAvailabilityStatus!)}');
  }
  return buffer.toString();
}
