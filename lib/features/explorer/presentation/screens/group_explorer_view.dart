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
    useEffect(() {
      final notifier = ref.read(canSwipeRootProvider.notifier);
      unawaited(Future.microtask(() => notifier.canSwipe = false));
      return () {
        if (context.mounted) {
          notifier.canSwipe = true;
        }
      };
    }, [groupId]);

    final stateAsync = ref.watch(groupExplorerControllerProvider(groupId));

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
            title: Text(state.title),
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
          body: CustomScrollView(
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
              if (genericsForList.isNotEmpty)
                SliverMainAxisGroup(
                  slivers: [
                    _buildStickySectionHeader(
                      context: context,
                      title: Strings.genericsAvailable,
                      badgeCount: genericsForList.length,
                      icon: LucideIcons.copy,
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final generic = genericsForList[index];
                          return _CompactGenericTile(
                            item: generic,
                            onTap: () => _openDetailSheet(context, generic),
                          );
                        },
                        childCount: genericsForList.length,
                      ),
                    ),
                  ],
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
              onPressed: () =>
                  ref.invalidate(groupExplorerControllerProvider(groupId)),
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
          if ((state.rawLabelAnsm?.isNotEmpty ?? false) ||
              (state.parsingMethod?.isNotEmpty ?? false) ||
              (state.princepsCisReference?.isNotEmpty ?? false)) ...[
            const Gap(AppDimens.spacingSm),
            _buildTechnicalInfo(context, state),
          ],
          _buildActionBar(context, state),
        ],
      ),
    );
  }

  Widget _buildMetadataTiles(
    BuildContext context,
    String priceLabel,
    String refundValue,
  ) {
    final theme = context.shadTheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.border),
        borderRadius: theme.radius,
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppDimens.spacingSm,
        horizontal: AppDimens.spacingMd,
      ),
      child: Row(
        children: [
          // Section Prix
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.banknote,
                      size: 14,
                      color: theme.colorScheme.mutedForeground,
                    ),
                    const Gap(4),
                    Text(
                      Strings.priceShort,
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const Gap(2),
                Text(
                  priceLabel,
                  style: theme.textTheme.p.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Séparateur vertical
          Container(
            height: 32,
            width: 1,
            color: theme.colorScheme.border,
            margin: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
          ),
          // Section Remboursement
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.percent,
                      size: 14,
                      color: theme.colorScheme.mutedForeground,
                    ),
                    const Gap(4),
                    Text(
                      Strings.refundShort,
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const Gap(2),
                Text(
                  refundValue,
                  style: theme.textTheme.p.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
    final typeBadge = ProductTypeBadge(memberType: member.memberType);
    final regulatoryBadgesWidget = RegulatoryBadges(
      isNarcotic: member.isNarcotic,
      isList1: member.isList1,
      isList2: member.isList2,
      isException: member.isException,
      isRestricted: member.isRestricted,
      isHospitalOnly: member.isHospitalOnly,
      isDental: member.isDental,
      isSurveillance: member.isSurveillance,
      isOtc: member.isOtc,
    );
    final hasRegulatoryBadges =
        member.isNarcotic ||
        member.isList1 ||
        member.isList2 ||
        member.isException ||
        member.isRestricted ||
        member.isHospitalOnly ||
        member.isDental ||
        member.isSurveillance ||
        member.isOtc;
    final labDisplay = member.parsedTitulaire.isEmpty
        ? Strings.unknownHolder
        : member.parsedTitulaire;
    final priceText = member.prixPublic != null
        ? formatEuro(member.prixPublic!)
        : null;
    final hasPrice = priceText != null;
    final refundLabel =
        member.trimmedRefundRate ??
        (hasPrice ? Strings.refundNotAvailable : null);
    final shouldShowRefund = refundLabel != null;

    final titleText =
        '${member.displayName}${member.dosageLabel != null && member.dosageLabel!.isNotEmpty ? ' • ${member.dosageLabel}' : ''}';

    final subtitleParts = <String>[];
    if (member.codeCip.isNotEmpty) {
      subtitleParts.add('${Strings.cip} ${member.codeCip}');
    }
    if (labDisplay.isNotEmpty && labDisplay != Strings.unknownHolder) {
      subtitleParts.add(labDisplay);
    }
    final subtitle = subtitleParts.isNotEmpty
        ? subtitleParts.join(' • ')
        : null;

    final hasFinancialBadge = hasPrice || shouldShowRefund;
    final detailsParts = <String>[];
    if (!hasFinancialBadge) {
      if (hasPrice) {
        detailsParts.add(priceText);
      }
      if (shouldShowRefund) {
        detailsParts.add(refundLabel);
      }
    }
    final details = detailsParts.isNotEmpty ? detailsParts.join(' • ') : null;

    final enhancedSubtitleParts = <String>[];
    if (subtitle != null) {
      enhancedSubtitleParts.add(subtitle);
    }
    if (member.trimmedAvailabilityStatus != null) {
      enhancedSubtitleParts.add(
        Strings.stockAlert(member.trimmedAvailabilityStatus!),
      );
    }
    final enhancedSubtitle = enhancedSubtitleParts.isNotEmpty
        ? enhancedSubtitleParts.join(' • ')
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MergeSemantics(
          child: Semantics(
            button: showNavigationIndicator && navigationGroupId != null,
            label: _buildMemberSemanticsLabel(member, subtitle, details),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: showNavigationIndicator && navigationGroupId != null
                      ? () => AutoRouter.of(context).push(
                          GroupExplorerRoute(groupId: navigationGroupId),
                        )
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spacingMd,
                      vertical: AppDimens.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: context.shadColors.border,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.scale(scale: 0.85, child: typeBadge),
                        const Gap(AppDimens.spacingSm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                titleText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: ShadTheme.of(context).textTheme.p
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                              if (hasFinancialBadge) ...[
                                const Gap(4),
                                FinancialBadge(
                                  refundRate: member.trimmedRefundRate,
                                  price: member.prixPublic,
                                ),
                              ],
                              if (enhancedSubtitle != null) ...[
                                const Gap(4),
                                Text(
                                  enhancedSubtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.shadTextTheme.small.copyWith(
                                    color: context.shadColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (details != null) ...[
                          const Gap(AppDimens.spacingSm),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              details,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: context.shadTextTheme.small.copyWith(
                                color: context.shadColors.mutedForeground,
                              ),
                            ),
                          ),
                        ],
                        if (showNavigationIndicator &&
                            navigationGroupId != null) ...[
                          const Gap(AppDimens.spacingXs),
                          const ExcludeSemantics(
                            child: Icon(LucideIcons.chevronRight, size: 16),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasRegulatoryBadges) ...[
          const Gap(AppDimens.spacingSm),
          regulatoryBadgesWidget,
        ],
        if (showNavigationIndicator && navigationGroupId != null) ...[
          const Gap(AppDimens.spacingSm),
          ShadButton.outline(
            onPressed: () => AutoRouter.of(context).push(
              GroupExplorerRoute(groupId: navigationGroupId),
            ),
            trailing: Icon(
              LucideIcons.arrowRight,
              size: AppDimens.iconSm,
              color: context.shadColors.foreground,
            ),
            child: const Text(Strings.showMedicamentDetails),
          ),
        ],
      ],
    );
  }

  String _buildMemberSemanticsLabel(
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
      buffer.write(
        ', ${Strings.stockAlert(member.trimmedAvailabilityStatus!)}',
      );
    }
    return buffer.toString();
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
      child: Row(
        children: [
          if (ansmUrl != null && ansmUrl.isNotEmpty) ...[
            Expanded(
              child: ShadButton.destructive(
                width: double.infinity,
                onPressed: () => _launchUrl(context, ansmUrl),
                leading: const Icon(
                  LucideIcons.triangleAlert,
                  size: AppDimens.iconSm,
                ),
                child: const Text(Strings.shortageAlert),
              ),
            ),
            const Gap(AppDimens.spacingXs),
          ],
          Expanded(
            child: ShadButton.secondary(
              onPressed: () => _launchUrl(context, ficheUrl),
              leading: Icon(
                LucideIcons.info,
                size: AppDimens.iconSm,
                color: context.shadColors.secondaryForeground,
              ),
              child: const Text(Strings.ficheInfo),
            ),
          ),
          const Gap(AppDimens.spacingXs),
          Expanded(
            child: ShadButton.outline(
              onPressed: () => _launchUrl(context, rcpUrl),
              leading: Icon(
                LucideIcons.fileText,
                size: AppDimens.iconSm,
                color: context.shadColors.foreground,
              ),
              child: const Text(Strings.rcpDocument),
            ),
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
    final theme = context.shadTheme;
    final lab = item.parsedTitulaire.isEmpty
        ? Strings.unknownHolder
        : item.parsedTitulaire;
    final hasPrice = item.prixPublic != null;
    final availability = item.trimmedAvailabilityStatus;
    final isStopped = item.isNotMarketed;
    final criticalBadge = availability != null
        ? Strings.stockAlert(availability)
        : (isStopped ? Strings.productStoppedBadge : null);

    return Semantics(
      button: true,
      label: '${item.displayName}, $lab',
      hint: Strings.tapToViewDetails,
      child: ShadButton.raw(
        onPressed: onTap,
        variant: ShadButtonVariant.ghost,
        width: double.infinity,
        padding: EdgeInsets.zero,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingMd,
            vertical: AppDimens.spacingSm,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.border),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : MediaQuery.sizeOf(context).width;

              return SizedBox(
                width: availableWidth,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        lab,
                        style: theme.textTheme.p.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasPrice) ...[
                          Icon(
                            LucideIcons.banknote,
                            size: 16,
                            color: theme.colorScheme.mutedForeground,
                          ),
                          const Gap(AppDimens.spacing2xs),
                        ],
                        if (item.isHospitalOnly) ...[
                          Icon(
                            LucideIcons.hospital,
                            size: 16,
                            color: theme.colorScheme.mutedForeground,
                          ),
                          const Gap(AppDimens.spacing2xs),
                        ],
                      ],
                    ),
                    if (criticalBadge != null) ...[
                      const Gap(AppDimens.spacingSm),
                      ShadBadge.destructive(
                        child: Text(
                          criticalBadge,
                          style: theme.textTheme.small,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
