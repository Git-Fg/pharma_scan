import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:forui/forui.dart';
import 'package:pharma_scan/core/router/routes.dart';
import 'package:pharma_scan/core/theme/app_colors.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/theme/badge_styles.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/info_label.dart';
import 'package:pharma_scan/core/widgets/ui_kit/section_header.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/models/grouped_by_product_model.dart';
import 'package:pharma_scan/features/explorer/providers/group_classification_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class GroupExplorerView extends HookConsumerWidget {
  const GroupExplorerView({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(groupDetailViewModelProvider(groupId));
    final relatedAsync = ref.watch(relatedPrincepsProvider(groupId));

    return detailAsync.when(
      data: (viewModel) {
        if (!viewModel.hasMembers) {
          return FScaffold(
            header: FHeader.nested(
              title: const Text(Strings.loadDetailsError),
              prefixes: [FHeaderAction.back(onPress: () => context.pop())],
            ),
            child: StatusView(
              type: StatusType.error,
              title: Strings.loadDetailsError,
              description: Strings.errorLoadingGroups,
              action: Semantics(
                button: true,
                label: Strings.backButtonLabel,
                hint: Strings.backButtonHint,
                child: FButton(
                  style: FButtonStyle.outline(),
                  onPress: () => context.pop(),
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

        return FScaffold(
          header: FHeader.nested(
            title: Text(viewModel.metadata.title),
            prefixes: [FHeaderAction.back(onPress: () => context.pop())],
          ),
          child: CustomScrollView(
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
              _buildSectionAccordion(
                context,
                Strings.princeps,
                princepsMembers.length,
                princepsMembers,
                sectionType: _ProductSectionType.princeps,
                icon: FIcons.star,
              ),
              _buildSectionAccordion(
                context,
                Strings.generics,
                genericMembers.length,
                genericMembers,
                sectionType: _ProductSectionType.generics,
                icon: FIcons.copy,
              ),
              if (shouldShowRelatedSection) ...[
                _buildSectionHeader(
                  Strings.relatedTherapies,
                  relatedMembers.length,
                  icon: FIcons.link,
                ),
                _buildRelatedList(
                  relatedMembers,
                  isLoading: relatedAsync.isLoading,
                ),
              ],
              const SliverToBoxAdapter(child: Gap(AppDimens.spacingXl)),
            ],
          ),
        );
      },
      loading: () => FScaffold(
        header: FHeader.nested(
          title: const Text(''),
          prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        ),
        child: const StatusView(type: StatusType.loading),
      ),
      error: (error, stackTrace) => FScaffold(
        header: FHeader.nested(
          title: const Text(Strings.loadDetailsError),
          prefixes: [FHeaderAction.back(onPress: () => context.pop())],
        ),
        child: StatusView(
          type: StatusType.error,
          title: Strings.loadDetailsError,
          description: error.toString(),
          action: Semantics(
            button: true,
            label: Strings.retryButtonLabel,
            hint: Strings.retryButtonHint,
            child: FButton(
              style: FButtonStyle.primary(),
              onPress: () =>
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
    final badgeStyles = context.theme.badgeStyles;
    final metadataBadges = <Widget>[
      if (metadata.distinctDosages.isNotEmpty)
        ...metadata.distinctDosages.map(
          (dosage) => FBadge(
            style: badgeStyles.condition,
            child: Text(
              '${Strings.dosagesLabel} $dosage',
              style: context.theme.typography.sm,
            ),
          ),
        ),
      if (metadata.distinctFormulations.isNotEmpty)
        ...metadata.distinctFormulations.map(
          (form) => FBadge(
            style: badgeStyles.princeps,
            child: Text(
              Strings.formWithValue(form),
              style: context.theme.typography.sm,
            ),
          ),
        ),
    ];
    final conditionBadges = viewModel.aggregatedConditions
        .whereType<String>()
        .map((condition) => condition.trim())
        .where((condition) => condition.isNotEmpty)
        .map(
          (condition) => FBadge(
            style: badgeStyles.condition,
            child: Text(
              condition,
              style: context.theme.typography.sm,
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
                  style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
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
    return FTileGroup(
      label: const Text(Strings.regulatoryFinancials),
      divider: FItemDivider.indented,
      children: [
        FTile(
          prefix: const Icon(FIcons.banknote),
          title: const Text(Strings.price),
          details: Text(priceLabel, style: context.theme.typography.base),
        ),
        FTile(
          prefix: const Icon(FIcons.percent),
          title: const Text(Strings.refundLabel),
          details: Text(refundValue, style: context.theme.typography.base),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, {IconData? icon}) {
    return SliverToBoxAdapter(
      child: SectionHeader(title: title, badgeCount: count, icon: icon),
    );
  }

  Widget _buildSectionAccordion(
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

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
        child: FAccordion(
          controller: FAccordionController(),
          children: [
            FAccordionItem(
              title: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimens.spacingXs,
                ),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: AppDimens.iconSm,
                        color: context.theme.colors.mutedForeground,
                      ),
                      const Gap(AppDimens.spacingXs),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: context.theme.typography.xl2, // h4 equivalent
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Gap(AppDimens.spacingXs),
                    Container(
                      decoration: BoxDecoration(
                        color: context.theme.colors.muted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text('$count', style: context.theme.typography.sm),
                    ),
                  ],
                ),
              ),
              child: _buildMemberColumn(
                context,
                members,
                sectionType: sectionType,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberColumn(
    BuildContext context,
    List<MedicationItem> members, {
    required _ProductSectionType sectionType,
  }) {
    if (members.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: members
          .map(
            (member) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spacingMd,
                vertical: AppDimens.spacing2xs,
              ),
              child: _buildMemberAccordion(
                context,
                member,
                sectionType: sectionType,
                showNavigationIndicator: false,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRelatedList(
    List<RelatedPrincepsItem> relatedMembers, {
    required bool isLoading,
  }) {
    if (isLoading && relatedMembers.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(AppDimens.spacingMd),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: FCircularProgress.loader(),
            ),
          ),
        ),
      );
    }

    if (relatedMembers.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final therapy = relatedMembers[index];

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingMd,
            vertical: AppDimens.spacing2xs,
          ),
          child: Semantics(
            button: true,
            label: Strings.associatedTherapySemantics(
              therapy.medication.displayName,
            ),
            child: _buildMemberAccordion(
              context,
              therapy.medication,
              sectionType: _ProductSectionType.related,
              showNavigationIndicator: true,
              navigationGroupId: therapy.groupId,
            ),
          ),
        );
      }, childCount: relatedMembers.length),
    );
  }

  Widget _buildMemberAccordion(
    BuildContext context,
    MedicationItem member, {
    required _ProductSectionType sectionType,
    required bool showNavigationIndicator,
    String? navigationGroupId,
  }) {
    final badgeStyles = context.theme.badgeStyles;
    final typeBadge = _buildTypeBadge(context, sectionType, badgeStyles);
    final regulatoryBadges = _buildRegulatoryBadges(context, member);
    final labDisplay = member.titulaire.isEmpty
        ? Strings.unknownHolder
        : member.titulaire;
    final priceText = member.price != null ? _formatEuro(member.price!) : null;
    final hasPrice = priceText != null;
    final refundLabel =
        member.refundRate ?? (hasPrice ? Strings.refundNotAvailable : null);
    final shouldShowRefund = refundLabel != null;

    // Build collapsed header title
    final titleText =
        '${member.displayName}${member.dosageLabel != null && member.dosageLabel!.isNotEmpty ? ' • ${member.dosageLabel}' : ''}';

    return FAccordion(
      controller: FAccordionController(),
      children: [
        FAccordionItem(
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Transform.scale(scale: 0.85, child: typeBadge),
              const Gap(AppDimens.spacingXs),
              Expanded(
                child: Text(
                  titleText,
                  style: context.theme.typography.base,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(AppDimens.spacingSm),
                InfoLabel(
                  text: '${Strings.cip} ${member.codeCip}',
                  icon: FIcons.barcode,
                  style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
                const Gap(AppDimens.spacingSm),
                InfoLabel(
                  text: labDisplay,
                  icon: FIcons.building2,
                  style: context.theme.typography.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
                if (hasPrice || shouldShowRefund) ...[
                  const Gap(AppDimens.spacingSm),
                  Row(
                    children: [
                      if (hasPrice)
                        Text(
                          priceText,
                          style: context.theme.typography.base.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (hasPrice && shouldShowRefund)
                        const Gap(AppDimens.spacingXs),
                      if (shouldShowRefund)
                        member.refundRate != null
                            ? FBadge(
                                style: badgeStyles.princeps,
                                child: Text(
                                  refundLabel,
                                  style: context.theme.typography.sm,
                                ),
                              )
                            : FBadge(
                                style: badgeStyles.condition,
                                child: Text(
                                  refundLabel,
                                  style: context.theme.typography.sm,
                                ),
                              ),
                    ],
                  ),
                ],
                if (member.availabilityStatus != null) ...[
                  const Gap(AppDimens.spacingSm),
                  FBadge(
                    style: badgeStyles.alert,
                    child: Text(
                      Strings.stockAlert(member.availabilityStatus!.trim()),
                      style: context.theme.typography.sm,
                    ),
                  ),
                ],
                if (regulatoryBadges.isNotEmpty) ...[
                  const Gap(AppDimens.spacingSm),
                  Wrap(
                    spacing: AppDimens.spacing2xs,
                    runSpacing: AppDimens.spacing2xs / 2,
                    children: regulatoryBadges,
                  ),
                ],
                if (showNavigationIndicator && navigationGroupId != null) ...[
                  const Gap(AppDimens.spacingMd),
                  FButton(
                    style: FButtonStyle.outline(),
                    onPress: () => GroupDetailRoute(
                      groupId: navigationGroupId,
                    ).push<void>(context),
                    suffix: Icon(
                      FIcons.arrowRight,
                      size: AppDimens.iconSm,
                      color: context.theme.colors.foreground,
                    ),
                    child: const Text(Strings.showMedicamentDetails),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeBadge(
    BuildContext context,
    _ProductSectionType sectionType,
    FBadgeStyles badgeStyles,
  ) {
    final (
      FBaseBadgeStyle Function(FBadgeStyle) resolver,
      String label,
    ) = switch (sectionType) {
      _ProductSectionType.princeps => (
        badgeStyles.princeps,
        Strings.badgePrinceps,
      ),
      _ProductSectionType.generics => (
        badgeStyles.generic,
        Strings.badgeGeneric,
      ),
      _ProductSectionType.related => (
        badgeStyles.princeps,
        Strings.badgePrinceps,
      ),
    };

    return FBadge(
      style: resolver,
      child: Text(label, style: context.theme.typography.sm),
    );
  }

  String _formatEuro(double value) {
    final fixed = value.toStringAsFixed(2).replaceAll('.', ',');
    return '$fixed €';
  }

  List<Widget> _buildRegulatoryBadges(
    BuildContext context,
    MedicationItem member,
  ) {
    final badgeStyles = context.theme.badgeStyles;
    final badges = <Widget>[];
    void addBadge(Widget badge) => badges.add(badge);

    if (member.isNarcotic) {
      addBadge(
        FBadge(
          style: badgeStyles.alert,
          child: Text(
            Strings.badgeNarcotic,
            style: context.theme.typography.sm,
          ),
        ),
      );
    }

    if (member.isList1) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.regulatoryRed),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            Strings.badgeList1,
            style: context.theme.typography.sm.copyWith(
              color: AppColors.regulatoryRed,
            ),
          ),
        ),
      );
    }

    if (member.isList2) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.regulatoryGreen),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            Strings.badgeList2,
            style: context.theme.typography.sm.copyWith(
              color: AppColors.regulatoryGreen,
            ),
          ),
        ),
      );
    }

    if (member.isException) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: AppColors.regulatoryPurple,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            Strings.badgeException,
            style: context.theme.typography.sm.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    if (member.isRestricted) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.regulatoryAmber),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            Strings.badgeRestricted,
            style: context.theme.typography.sm.copyWith(
              color: AppColors.regulatoryAmber,
            ),
          ),
        ),
      );
    }

    if (member.isHospitalOnly) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: AppColors.regulatoryGray,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            Strings.hospitalBadge,
            style: context.theme.typography.sm.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    if (member.isDental) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: context.theme.colors.secondary,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            Strings.badgeDental,
            style: context.theme.typography.sm.copyWith(
              color: context.theme.colors.secondaryForeground,
            ),
          ),
        ),
      );
    }

    if (member.isOtc) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: AppColors.regulatoryGreen.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            Strings.badgeOtc,
            style: context.theme.typography.sm.copyWith(
              color: AppColors.regulatoryGreen,
            ),
          ),
        ),
      );
    }

    if (member.isSurveillance) {
      addBadge(
        Container(
          decoration: BoxDecoration(
            color: AppColors.regulatoryYellow,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            Strings.badgeSurveillance,
            style: context.theme.typography.sm.copyWith(color: Colors.black),
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
        'https://base-donnees-publique.medicaments.gouv.fr/affichageDoc.php?specid=$cisCode&typedoc=R';

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
                        color: context.theme.colors.destructive,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      color: context.theme.colors.destructive.withValues(
                        alpha: 0.1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FIcons.triangleAlert,
                          size: AppDimens.iconSm,
                          color: context.theme.colors.destructive,
                        ),
                        const Gap(AppDimens.spacingXs),
                        Text(
                          Strings.shortageAlert,
                          style: context.theme.typography.sm.copyWith(
                            color: context.theme.colors.destructive,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Gap(8),
          ],
          Expanded(
            child: FButton(
              style: FButtonStyle.secondary(),
              onPress: () => _launchUrl(context, ficheUrl),
              prefix: Icon(
                FIcons.info,
                size: AppDimens.iconSm,
                color: context.theme.colors.secondaryForeground,
              ),
              child: const Text(Strings.ficheInfo),
            ),
          ),
          const Gap(8),
          Expanded(
            child: FButton(
              style: FButtonStyle.outline(),
              onPress: () => _launchUrl(context, rcpUrl),
              prefix: Icon(
                FIcons.fileText,
                size: AppDimens.iconSm,
                color: context.theme.colors.foreground,
              ),
              child: const Text(Strings.rcpDocument),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        showFToast(
          context: context,
          title: const Text(Strings.error),
          description: Text('Impossible d\'ouvrir l\'URL: $url'),
          icon: const Icon(FIcons.triangleAlert),
        );
      }
    }
  }
}

enum _ProductSectionType { princeps, generics, related }
