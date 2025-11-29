import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/router/app_router.dart';
import 'package:pharma_scan/core/services/logger_service.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/section_header_delegate.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/models/grouped_by_product_model.dart';
import 'package:pharma_scan/features/explorer/providers/group_classification_provider.dart';
import 'package:pharma_scan/theme/pharma_colors.dart';
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
    final detailAsync = ref.watch(groupDetailViewModelProvider(groupId));
    final relatedAsync = ref.watch(relatedPrincepsProvider(groupId));

    return detailAsync.when(
      data: (viewModel) {
        if (!viewModel.hasMembers) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(Strings.loadDetailsError),
              leading: IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => context.router.maybePop(),
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
                  onPressed: () => context.router.maybePop(),
                  child: const Text(Strings.back),
                ),
              ),
            ),
          );
        }

        final princepsMembers = viewModel.princeps;
        final genericMembers = viewModel.generics;
        final relatedMembers =
            relatedAsync.value ?? const <RelatedPrincepsItem>[];
        final shouldShowRelatedSection =
            relatedAsync.isLoading || relatedMembers.isNotEmpty;

        return Scaffold(
          appBar: AppBar(
            title: Text(viewModel.metadata.title),
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => context.router.maybePop(),
            ),
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildAppBarContent(
                  context,
                  viewModel,
                  princepsMembers.length,
                  genericMembers.length,
                  relatedMembers.length,
                ),
              ),
              _buildSectionSliver(
                context,
                Strings.princeps,
                princepsMembers.length,
                princepsMembers,
                sectionType: _ProductSectionType.princeps,
                icon: LucideIcons.star,
              ),
              _buildSectionSliver(
                context,
                Strings.generics,
                genericMembers.length,
                genericMembers,
                sectionType: _ProductSectionType.generics,
                icon: LucideIcons.copy,
              ),
              if (shouldShowRelatedSection)
                _buildRelatedSectionSliver(
                  context,
                  relatedMembers,
                  isLoading: relatedAsync.isLoading,
                ),
              const SliverToBoxAdapter(child: Gap(AppDimens.spacingXl)),
            ],
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
        body: const StatusView(type: StatusType.loading),
      ),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(
          title: const Text(Strings.loadDetailsError),
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => context.router.maybePop(),
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
                  ref.invalidate(groupDetailViewModelProvider(groupId)),
              child: const Text(Strings.retry),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarContent(
    BuildContext context,
    GroupedProductsViewModel viewModel,
    int princepsCount,
    int genericsCount,
    int relatedCount,
  ) {
    final metadata = viewModel.metadata;
    final theme = ShadTheme.of(context);
    final metadataBadges = <Widget>[
      if (metadata.distinctDosages.isNotEmpty)
        ...metadata.distinctDosages.map(
          (dosage) => ShadBadge.outline(
            child: Text(
              '${Strings.dosagesLabel} $dosage',
              style: theme.textTheme.small,
            ),
          ),
        ),
      if (metadata.distinctFormulations.isNotEmpty)
        ...metadata.distinctFormulations.map(
          (form) => ShadBadge.secondary(
            child: Text(
              Strings.formWithValue(form),
              style: theme.textTheme.small,
            ),
          ),
        ),
    ];
    final conditionBadges = viewModel.aggregatedConditions
        .whereType<String>()
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
    final priceLabel = viewModel.priceLabel ?? Strings.priceUnavailable;
    final refundValue = viewModel.refundLabel ?? Strings.refundNotAvailable;

    final summaryLines = <String>[
      Strings.summaryLine(princepsCount, genericsCount),
      if (metadata.commonPrincipes.isNotEmpty)
        '${Strings.activeIngredientsLabel} : ${metadata.commonPrincipes.join(', ')}',
      if (relatedCount > 0) Strings.associatedPrincepsCount(relatedCount),
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
          _buildMetadataTiles(context, priceLabel, refundValue),
          const Gap(AppDimens.spacingSm),
          _buildActionBar(context, viewModel),
          if (metadataBadges.isNotEmpty) ...[
            const Gap(AppDimens.spacingSm),
            Wrap(
              spacing: AppDimens.spacingXs,
              runSpacing: AppDimens.spacing2xs,
              children: metadataBadges,
            ),
          ],
          if (conditionBadges.isNotEmpty) ...[
            const Gap(AppDimens.spacingSm),
            Wrap(
              spacing: AppDimens.spacing2xs,
              runSpacing: AppDimens.spacing2xs,
              children: conditionBadges,
            ),
          ],
          if (summaryLines.isNotEmpty) ...[
            const Gap(AppDimens.spacingSm),
            for (final line in summaryLines)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: AppDimens.spacing2xs / 2,
                ),
                child: Text(
                  line,
                  style: ShadTheme.of(context).textTheme.small.copyWith(
                    color: ShadTheme.of(context).colorScheme.mutedForeground,
                  ),
                ),
              ),
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
    final theme = ShadTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimens.spacingMd,
            bottom: AppDimens.spacingXs,
          ),
          child: Text(Strings.regulatoryFinancials, style: theme.textTheme.h4),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
          ),
          child: InkWell(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingMd,
                vertical: AppDimens.spacingSm,
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.banknote),
                  const SizedBox(width: AppDimens.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Strings.price, style: theme.textTheme.p),
                        const SizedBox(height: 4),
                        Text(priceLabel, style: theme.textTheme.p),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Divider(height: 1, color: theme.colorScheme.border),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.colorScheme.border)),
          ),
          child: InkWell(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingMd,
                vertical: AppDimens.spacingSm,
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.percent),
                  const SizedBox(width: AppDimens.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(Strings.refundLabel, style: theme.textTheme.p),
                        const SizedBox(height: 4),
                        Text(refundValue, style: theme.textTheme.p),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionSliver(
    BuildContext context,
    String title,
    int count,
    List<MedicationItem> members, {
    required _ProductSectionType sectionType,
    IconData? icon,
  }) {
    if (members.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        // Sticky Header
        SliverPersistentHeader(
          delegate: SectionHeaderDelegate(
            title: title,
            badgeCount: count,
            icon: icon,
            textScaler: MediaQuery.textScalerOf(context),
          ),
          pinned: true,
        ),
        // Member List
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
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

  Widget _buildRelatedSectionSliver(
    BuildContext context,
    List<RelatedPrincepsItem> relatedMembers, {
    required bool isLoading,
  }) {
    if (isLoading && relatedMembers.isEmpty) {
      return SliverMainAxisGroup(
        slivers: [
          SliverPersistentHeader(
            delegate: SectionHeaderDelegate(
              title: Strings.relatedTherapies,
              icon: LucideIcons.link,
              textScaler: MediaQuery.textScalerOf(context),
            ),
            pinned: true,
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
        SliverPersistentHeader(
          delegate: SectionHeaderDelegate(
            title: Strings.relatedTherapies,
            badgeCount: relatedMembers.length,
            icon: LucideIcons.link,
            textScaler: MediaQuery.textScalerOf(context),
          ),
          pinned: true,
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
                    therapy.medication.displayName,
                  ),
                  child: _buildMemberTile(
                    context,
                    therapy.medication,
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
    MedicationItem member, {
    required _ProductSectionType sectionType,
    required bool showNavigationIndicator,
    String? navigationGroupId,
  }) {
    final typeBadge = _buildTypeBadge(context, sectionType);
    final regulatoryBadges = _buildRegulatoryBadges(context, member);
    final labDisplay = member.titulaire.isEmpty
        ? Strings.unknownHolder
        : member.titulaire;
    final priceText = member.price != null ? _formatEuro(member.price!) : null;
    final hasPrice = priceText != null;
    final refundLabel =
        member.refundRate ?? (hasPrice ? Strings.refundNotAvailable : null);
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
    if (member.availabilityStatus != null) {
      enhancedSubtitleParts.add(
        Strings.stockAlert(member.availabilityStatus!.trim()),
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
        if (regulatoryBadges.isNotEmpty) ...[
          const Gap(AppDimens.spacingSm),
          Wrap(
            spacing: AppDimens.spacing2xs,
            runSpacing: AppDimens.spacing2xs / 2,
            children: regulatoryBadges,
          ),
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
    MedicationItem member,
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
    if (member.availabilityStatus != null) {
      buffer.write(
        ', ${Strings.stockAlert(member.availabilityStatus!.trim())}',
      );
    }
    return buffer.toString();
  }

  Widget _buildTypeBadge(
    BuildContext context,
    _ProductSectionType sectionType,
  ) {
    final theme = ShadTheme.of(context);
    final label = switch (sectionType) {
      _ProductSectionType.princeps => Strings.badgePrinceps,
      _ProductSectionType.generics => Strings.badgeGeneric,
      _ProductSectionType.related => Strings.badgePrinceps,
    };
    return switch (sectionType) {
      _ProductSectionType.princeps => ShadBadge.secondary(
        child: Text(label, style: theme.textTheme.small),
      ),
      _ProductSectionType.generics => ShadBadge(
        child: Text(label, style: theme.textTheme.small),
      ),
      _ProductSectionType.related => ShadBadge.secondary(
        child: Text(label, style: theme.textTheme.small),
      ),
    };
  }

  String _formatEuro(double value) {
    final fixed = value.toStringAsFixed(2).replaceAll('.', ',');
    return '$fixed €';
  }

  List<Widget> _buildRegulatoryBadges(
    BuildContext context,
    MedicationItem member,
  ) {
    // WHY: PharmaColors is always registered in theme extensions (see lib/theme/theme.dart)
    // Flow analysis confirms this is non-null, so we can safely assert
    final pharmaColors = Theme.of(context).extension<PharmaColors>()!;
    final theme = ShadTheme.of(context);
    final badges = <Widget>[];
    void addBadge(Widget badge) => badges.add(badge);

    if (member.isNarcotic) {
      addBadge(
        ShadBadge.destructive(
          child: Text(Strings.badgeNarcotic, style: theme.textTheme.small),
        ),
      );
    }

    if (member.isList1) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: pharmaColors.regulatoryRed),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXs,
            vertical: AppDimens.spacing2xs,
          ),
          child: Text(
            Strings.badgeList1,
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: pharmaColors.regulatoryRed),
          ),
        ),
      );
    }

    if (member.isList2) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: pharmaColors.regulatoryGreen),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXs,
            vertical: AppDimens.spacing2xs,
          ),
          child: Text(
            Strings.badgeList2,
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: pharmaColors.regulatoryGreen),
          ),
        ),
      );
    }

    if (member.isException) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: pharmaColors.regulatoryPurple,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXs,
            vertical: AppDimens.spacing2xs,
          ),
          child: Text(
            Strings.badgeException,
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    if (member.isRestricted) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: pharmaColors.regulatoryAmber),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXs,
            vertical: AppDimens.spacing2xs,
          ),
          child: Text(
            Strings.badgeRestricted,
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: pharmaColors.regulatoryAmber),
          ),
        ),
      );
    }

    if (member.isHospitalOnly) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: pharmaColors.regulatoryGray,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXs,
            vertical: AppDimens.spacing2xs,
          ),
          child: Text(
            Strings.hospitalBadge,
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    if (member.isDental) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: ShadTheme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXs,
            vertical: AppDimens.spacing2xs,
          ),
          child: Text(
            Strings.badgeDental,
            style: ShadTheme.of(context).textTheme.small.copyWith(
              color: ShadTheme.of(context).colorScheme.secondaryForeground,
            ),
          ),
        ),
      );
    }

    if (member.isOtc) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: pharmaColors.regulatoryGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXs,
            vertical: AppDimens.spacing2xs,
          ),
          child: Text(
            Strings.badgeOtc,
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: pharmaColors.regulatoryGreen),
          ),
        ),
      );
    }

    if (member.isSurveillance) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: pharmaColors.regulatoryYellow,
            borderRadius: BorderRadius.circular(AppDimens.radiusSm / 2),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingXs,
            vertical: AppDimens.spacing2xs,
          ),
          child: Text(
            Strings.badgeSurveillance,
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: Colors.black),
          ),
        ),
      );
    }

    return badges;
  }

  Widget _buildActionBar(
    BuildContext context,
    GroupedProductsViewModel viewModel,
  ) {
    final cisCode = viewModel.princepsCisCode;
    final ansmUrl = viewModel.ansmAlertUrl;

    if (cisCode == null || cisCode.isEmpty) {
      return const SizedBox.shrink();
    }

    final ficheUrl =
        'https://base-donnees-publique.medicaments.gouv.fr/extrait.php?specid=$cisCode';
    final rcpUrl =
        'https://base-donnees-publique.medicaments.gouv.fr/medicament/$cisCode/extrait#tab-rcp';

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
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.spacingMd,
                      vertical: AppDimens.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: ShadTheme.of(context).colorScheme.destructive,
                      ),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
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
      // WHY: Try to launch directly - canLaunchUrl can return false for valid URLs
      // Better to attempt launch and handle exceptions
      await launchUrl(uri);
    } on Exception catch (e) {
      // WHY: Handle specific exceptions with user-friendly messages
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
}

enum _ProductSectionType { princeps, generics, related }
