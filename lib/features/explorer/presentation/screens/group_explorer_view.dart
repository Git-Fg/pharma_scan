import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/config/data_sources.dart';
import 'package:pharma_scan/core/database/database.dart';
import 'package:pharma_scan/core/providers/navigation_provider.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/formatters.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/swipe_back_detector.dart';
import 'package:pharma_scan/core/widgets/ui_kit/product_type_badge.dart';
import 'package:pharma_scan/core/widgets/ui_kit/regulatory_badges.dart';
import 'package:pharma_scan/core/widgets/ui_kit/section_header.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/domain/extensions/view_group_detail_extensions.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/group_explorer_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/group_explorer_state.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/rcp_shortcuts_accordion.dart';
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
    // Disable root-level swiping when in nested route
    useEffect(() {
      ref.read(canSwipeRootProvider.notifier).canSwipe = false;
      return () {
        // Re-enable root-level swiping when leaving this route
        ref.read(canSwipeRootProvider.notifier).canSwipe = true;
      };
    }, [groupId]);

    final stateAsync = ref.watch(groupExplorerControllerProvider(groupId));

    return stateAsync.when(
      data: (GroupExplorerState state) {
        if (state.princeps.isEmpty && state.generics.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(Strings.loadDetailsError),
              leading: IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => context.router.maybePop(),
              ),
            ),
            body: SwipeBackDetector(
              child: StatusView(
                type: StatusType.error,
                title: Strings.loadDetailsError,
                description: Strings.errorLoadingGroups,
                action: Semantics(
                  button: true,
                  label: Strings.backButtonLabel,
                  hint: Strings.backButtonHint,
                  child: ShadButton.outline(
                    onPressed: () => context.router.maybePop(),
                    child: const Text(Strings.back),
                  ),
                ),
              ),
            ),
          );
        }

        final shouldShowRelatedSection = state.related.isNotEmpty;

        // Detect if we're in Scanner context
        final isInScannerContext = _isInScannerContext(context);

        return Scaffold(
          appBar: AppBar(
            title: Text(state.title),
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => context.router.maybePop(),
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
          body: SwipeBackDetector(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildAppBarContent(
                        context,
                        state,
                      ),
                      if (state.princepsCisCode != null &&
                          state.princepsCisCode!.isNotEmpty) ...[
                        const Gap(AppDimens.spacingSm),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimens.spacingMd,
                          ),
                          child: RcpShortcutsAccordion(
                            cisCode: state.princepsCisCode!,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildSectionSliver(
                  context,
                  Strings.princeps,
                  state.princeps.length,
                  state.princeps,
                  sectionType: _ProductSectionType.princeps,
                  icon: LucideIcons.star,
                ),
                _buildSectionSliver(
                  context,
                  Strings.generics,
                  state.generics.length,
                  state.generics,
                  sectionType: _ProductSectionType.generics,
                  icon: LucideIcons.copy,
                ),
                if (shouldShowRelatedSection)
                  _buildRelatedSectionSliver(
                    context,
                    state.related,
                    isLoading: false,
                  ),
                const SliverToBoxAdapter(child: Gap(AppDimens.spacingXl)),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text(Strings.loading),
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => context.router.maybePop(),
          ),
        ),
        body: const SwipeBackDetector(
          child: StatusView(type: StatusType.loading),
        ),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(
          title: const Text(Strings.loadDetailsError),
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => context.router.maybePop(),
          ),
        ),
        body: SwipeBackDetector(
          child: StatusView(
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
      ),
    );
  }

  Widget _buildAppBarContent(
    BuildContext context,
    GroupExplorerState state,
  ) {
    final theme = ShadTheme.of(context);
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
          // 1. Title/Subtitle Section (Molecule > Brand)
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
          // 2. Unified Badges Row
          if (allBadges.isNotEmpty) ...[
            const Gap(AppDimens.spacingSm),
            Wrap(
              spacing: AppDimens.spacing2xs,
              runSpacing: AppDimens.spacing2xs,
              children: allBadges,
            ),
          ],
          // 3. Financial Row
          const Gap(AppDimens.spacingSm),
          _buildMetadataTiles(context, priceLabel, refundValue),
          // 4. Action Buttons
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
    final theme = ShadTheme.of(context);

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

  Widget _buildSectionSliver(
    BuildContext context,
    String title,
    int count,
    List<ViewGroupDetail> members, {
    required _ProductSectionType sectionType,
    IconData? icon,
  }) {
    if (members.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    // 1. Group members by pharmaceutical form
    final groupedByForm = groupBy(
      members,
      (m) => m.formLabel ?? Strings.notDefined,
    );

    // 2. Decide layout strategy based on form count
    // Case A: Single form -> Use Standard Flat List (Cleaner, no extra click)
    if (groupedByForm.keys.length <= 1) {
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: SectionHeader(
              title: title,
              badgeCount: count,
              icon: icon,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spacingMd,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final member = members[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.spacing2xs,
                  ),
                  child: _buildMemberTile(
                    context,
                    member,
                    sectionType: sectionType,
                    showNavigationIndicator: false,
                  ),
                );
              }, childCount: members.length),
            ),
          ),
        ],
      );
    }

    // Case B: Multiple forms -> Use Accordion to reduce scrolling
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: SectionHeader(
            title: title,
            badgeCount: count,
            icon: icon,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
          sliver: SliverToBoxAdapter(
            child: ShadAccordion<String>.multiple(
              children: groupedByForm.entries.map((entry) {
                final formName = entry.key;
                final formMembers = entry.value;

                return ShadAccordionItem(
                  value: formName,
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          formName,
                          style: ShadTheme.of(context).textTheme.p.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      ShadBadge.outline(
                        child: Text('${formMembers.length}'),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: formMembers.map((member) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimens.spacing2xs,
                        ),
                        child: _buildMemberTile(
                          context,
                          member,
                          sectionType: sectionType,
                          showNavigationIndicator: false,
                        ),
                      );
                    }).toList(),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedSectionSliver(
    BuildContext context,
    List<ViewGroupDetail> relatedMembers, {
    required bool isLoading,
  }) {
    if (isLoading && relatedMembers.isEmpty) {
      return SliverMainAxisGroup(
        slivers: [
          buildStickySectionHeader(
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
        // Sticky Header
        buildStickySectionHeader(
          context: context,
          title: Strings.relatedTherapies,
          badgeCount: relatedMembers.length,
          icon: LucideIcons.link,
        ),
        // Related List
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
                    sectionType: _ProductSectionType.related,
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
    ViewGroupDetail member, {
    required _ProductSectionType sectionType,
    required bool showNavigationIndicator,
    String? navigationGroupId,
  }) {
    final productType = switch (sectionType) {
      _ProductSectionType.princeps => ProductType.princeps,
      _ProductSectionType.generics => ProductType.generic,
      _ProductSectionType.related => ProductType.princeps,
    };
    final typeBadge = ProductTypeBadge(type: productType);
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

    // Build title text
    final titleText =
        '${member.displayName}${member.dosageLabel != null && member.dosageLabel!.isNotEmpty ? ' • ${member.dosageLabel}' : ''}';

    // Build subtitle with key information
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

    // Build details (price and refund)
    final detailsParts = <String>[];
    if (hasPrice) {
      detailsParts.add(priceText);
    }
    if (shouldShowRefund) {
      detailsParts.add(refundLabel);
    }
    final details = detailsParts.isNotEmpty ? detailsParts.join(' • ') : null;

    // Build enhanced subtitle with availability status if present
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
            child: InkWell(
              onTap: showNavigationIndicator && navigationGroupId != null
                  ? () => context.router.push(
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
                      color: ShadTheme.of(context).colorScheme.border,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.scale(scale: 0.85, child: typeBadge),
                    const SizedBox(width: AppDimens.spacingSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            titleText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ShadTheme.of(
                              context,
                            ).textTheme.p.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (enhancedSubtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              enhancedSubtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: ShadTheme.of(context).textTheme.small
                                  .copyWith(
                                    color: ShadTheme.of(
                                      context,
                                    ).colorScheme.mutedForeground,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (details != null) ...[
                      const SizedBox(width: AppDimens.spacingSm),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: ShadTheme.of(context).textTheme.small.copyWith(
                            color: ShadTheme.of(
                              context,
                            ).colorScheme.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                    if (showNavigationIndicator &&
                        navigationGroupId != null) ...[
                      const SizedBox(width: AppDimens.spacingXs),
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
        // Regulatory badges below tile (they don't fit in custom tile structure)
        if (hasRegulatoryBadges) ...[
          const Gap(AppDimens.spacingSm),
          regulatoryBadgesWidget,
        ],
        // Navigation button for related therapies
        if (showNavigationIndicator && navigationGroupId != null) ...[
          const Gap(AppDimens.spacingSm),
          ShadButton.outline(
            onPressed: () => context.router.push(
              GroupExplorerRoute(groupId: navigationGroupId),
            ),
            trailing: Icon(
              LucideIcons.arrowRight,
              size: AppDimens.iconSm,
              color: ShadTheme.of(context).colorScheme.foreground,
            ),
            child: const Text(Strings.showMedicamentDetails),
          ),
        ],
      ],
    );
  }

  String _buildMemberSemanticsLabel(
    ViewGroupDetail member,
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
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _launchUrl(context, ansmUrl),
                  borderRadius: ShadTheme.of(context).radius,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spacingMd,
                      vertical: AppDimens.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: ShadTheme.of(context).colorScheme.destructive,
                      ),
                      borderRadius: ShadTheme.of(context).radius,
                      color: ShadTheme.of(
                        context,
                      ).colorScheme.destructive.withValues(alpha: 0.1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.triangleAlert,
                          size: AppDimens.iconSm,
                          color: ShadTheme.of(context).colorScheme.destructive,
                        ),
                        const Gap(AppDimens.spacingXs),
                        Text(
                          Strings.shortageAlert,
                          style: ShadTheme.of(context).textTheme.small.copyWith(
                            color: ShadTheme.of(
                              context,
                            ).colorScheme.destructive,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                color: ShadTheme.of(context).colorScheme.secondaryForeground,
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
                color: ShadTheme.of(context).colorScheme.foreground,
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
    try {
      final parentRoute = context.router.parent();
      return parentRoute?.routeData.name == 'ScannerTabRoute';
    } on Exception {
      return false;
    }
  }

  void _navigateToExplorer(BuildContext context, String groupId) {
    // Navigate to Explorer tab and push the same group
    unawaited(
      context.router.navigate(const ExplorerTabRoute()).then((_) {
        if (context.mounted) {
          unawaited(
            context.router.push(GroupExplorerRoute(groupId: groupId)),
          );
        }
      }),
    );
  }
}

enum _ProductSectionType { princeps, generics, related }
