import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/core/theme/app_colors.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/info_label.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_back_header.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_badges.dart';
import 'package:pharma_scan/core/widgets/ui_kit/section_header.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/models/grouped_by_product_model.dart';
import 'package:pharma_scan/features/explorer/providers/group_classification_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class GroupExplorerView extends ConsumerWidget {
  const GroupExplorerView({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final detailAsync = ref.watch(groupDetailViewModelProvider(groupId));
    final relatedAsync = ref.watch(relatedPrincepsProvider(groupId));

    return detailAsync.when(
      data: (viewModel) {
        if (!viewModel.hasMembers) {
          return Scaffold(
            body: StatusView(
              type: StatusType.error,
              title: Strings.loadDetailsError,
              description: Strings.errorLoadingGroups,
              action: ShadButton(
                onPressed: () => context.pop(),
                child: const Text(Strings.back),
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
          backgroundColor: theme.colorScheme.background,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildAppBarContent(
                    context,
                    theme,
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
                  icon: LucideIcons.star,
                ),
                _buildSectionAccordion(
                  context,
                  Strings.generics,
                  genericMembers.length,
                  genericMembers,
                  sectionType: _ProductSectionType.generics,
                  icon: LucideIcons.copy,
                ),
                if (shouldShowRelatedSection) ...[
                  _buildSectionHeader(
                    Strings.relatedTherapies,
                    relatedMembers.length,
                    icon: LucideIcons.link,
                  ),
                  _buildRelatedList(
                    relatedMembers,
                    isLoading: relatedAsync.isLoading,
                  ),
                ],
                const SliverToBoxAdapter(child: Gap(AppDimens.spacingXl)),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: StatusView(type: StatusType.loading)),
      error: (error, stackTrace) => Scaffold(
        body: StatusView(
          type: StatusType.error,
          title: Strings.loadDetailsError,
          description: error.toString(),
          action: ShadButton(
            onPressed: () =>
                ref.invalidate(groupDetailViewModelProvider(groupId)),
            child: const Text(Strings.retry),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarContent(
    BuildContext context,
    ShadThemeData theme,
    GroupedProductsViewModel viewModel,
    int princepsCount,
    int genericsCount,
    int relatedCount,
  ) {
    final metadata = viewModel.metadata;
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
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.secondaryForeground,
              ),
            ),
          ),
        ),
    ];

    final summaryLines = <String>[
      Strings.summaryLine(princepsCount, genericsCount),
      if (metadata.commonPrincipes.isNotEmpty)
        '${Strings.activeIngredientsLabel} : ${metadata.commonPrincipes.join(', ')}',
      if (relatedCount > 0) Strings.associatedPrincepsCount(relatedCount),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PharmaBackHeader(
          title: metadata.title,
          backLabel: Strings.backToSearch,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spacingMd,
            AppDimens.spacingSm,
            AppDimens.spacingMd,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GroupIdentityHeader(viewModel: viewModel),
              _buildActionBar(context, theme, viewModel),
              if (metadataBadges.isNotEmpty) ...[
                const Gap(AppDimens.spacingSm),
                Wrap(
                  spacing: AppDimens.spacingXs,
                  runSpacing: AppDimens.spacing2xs,
                  children: metadataBadges,
                ),
              ],
              if (summaryLines.isNotEmpty) ...[
                const Gap(AppDimens.spacingSm),
                for (final line in summaryLines)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppDimens.spacing2xs / 2,
                    ),
                    child: Text(line, style: theme.textTheme.muted),
                  ),
              ],
            ],
          ),
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

    final theme = ShadTheme.of(context);
    final sectionId = '${sectionType.name}_$title';

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.spacingMd),
        child: ShadAccordion<String>(
          children: [
            ShadAccordionItem(
              value: sectionId,
              title: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimens.spacingXs),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: AppDimens.iconSm,
                        color: theme.colorScheme.mutedForeground,
                      ),
                      const Gap(AppDimens.spacingXs),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.h4,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const Gap(AppDimens.spacingXs),
                    ShadBadge(
                      backgroundColor: theme.colorScheme.muted,
                      child: Text(
                        '$count',
                        style: theme.textTheme.small.copyWith(
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
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
                ShadTheme.of(context),
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
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
              ShadTheme.of(context),
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
    ShadThemeData theme,
    MedicationItem member, {
    required _ProductSectionType sectionType,
    required bool showNavigationIndicator,
    String? navigationGroupId,
  }) {
    final typeBadge = switch (sectionType) {
      _ProductSectionType.princeps => const PrincepsBadge(),
      _ProductSectionType.generics => const GenericBadge(),
      _ProductSectionType.related => const PrincepsBadge(),
    };
    final regulatoryBadges = _buildRegulatoryBadges(theme, member);
    final labDisplay = member.titulaire.isEmpty
        ? Strings.unknownHolder
        : member.titulaire;
    final priceText = member.price != null ? _formatEuro(member.price!) : null;
    final hasPrice = priceText != null;
    final refundLabel =
        member.refundRate ?? (hasPrice ? Strings.refundNotAvailable : null);
    final shouldShowRefund = refundLabel != null;

    // Build collapsed header title
    final titleText = '${member.displayName}${member.dosageLabel != null && member.dosageLabel!.isNotEmpty ? ' • ${member.dosageLabel}' : ''}';

    return ShadAccordion<MedicationItem>(
      children: [
        ShadAccordionItem(
          value: member,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Transform.scale(
                scale: 0.85,
                child: typeBadge,
              ),
              const Gap(AppDimens.spacingXs),
              Expanded(
                child: Text(
                  titleText,
                  style: theme.textTheme.p.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                  icon: LucideIcons.barcode,
                  style: theme.textTheme.muted,
                ),
                const Gap(AppDimens.spacingSm),
                InfoLabel(
                  text: labDisplay,
                  icon: LucideIcons.building2,
                  style: theme.textTheme.muted,
                ),
                if (hasPrice || shouldShowRefund) ...[
                  const Gap(AppDimens.spacingSm),
                  Row(
                    children: [
                      if (hasPrice)
                        Text(
                          priceText,
                          style: theme.textTheme.p.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (hasPrice && shouldShowRefund)
                        const Gap(AppDimens.spacingXs),
                      if (shouldShowRefund)
                        member.refundRate != null
                            ? ShadBadge.secondary(
                                child: Text(
                                  refundLabel,
                                  style: theme.textTheme.small.copyWith(
                                    color: theme.colorScheme.secondaryForeground,
                                  ),
                                ),
                              )
                            : ShadBadge.outline(
                                child: Text(
                                  refundLabel,
                                  style: theme.textTheme.small,
                                ),
                              ),
                    ],
                  ),
                ],
                if (member.availabilityStatus != null) ...[
                  const Gap(AppDimens.spacingSm),
                  ShadBadge.destructive(
                    child: Text(
                      Strings.stockAlert(member.availabilityStatus!.trim()),
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.destructiveForeground,
                        fontWeight: FontWeight.w700,
                      ),
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
                  ShadButton.outline(
                    width: double.infinity,
                    onPressed: () =>
                        context.push(AppRoutes.groupDetail(navigationGroupId)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          Strings.showMedicamentDetails,
                          style: theme.textTheme.small,
                        ),
                        const Gap(AppDimens.spacingXs),
                        Icon(
                          LucideIcons.arrowRight,
                          size: AppDimens.iconSm,
                          color: theme.colorScheme.foreground,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatEuro(double value) {
    final fixed = value.toStringAsFixed(2).replaceAll('.', ',');
    return '$fixed €';
  }

  List<Widget> _buildRegulatoryBadges(
    ShadThemeData theme,
    MedicationItem member,
  ) {
    final badges = <Widget>[];
    void addBadge(Widget badge) => badges.add(badge);

    if (member.isNarcotic) {
      addBadge(
        ShadBadge.destructive(
          child: Text(
            Strings.badgeNarcotic,
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.destructiveForeground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    if (member.isList1) {
      addBadge(
        ShadBadge.outline(
          child: Text(
            Strings.badgeList1,
            style: theme.textTheme.small.copyWith(
              color: AppColors.regulatoryRed,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (member.isList2) {
      addBadge(
        ShadBadge.outline(
          child: Text(
            Strings.badgeList2,
            style: theme.textTheme.small.copyWith(
              color: AppColors.regulatoryGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (member.isException) {
      addBadge(
        ShadBadge.secondary(
          backgroundColor: AppColors.regulatoryPurple,
          child: Text(
            Strings.badgeException,
            style: theme.textTheme.small.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (member.isRestricted) {
      addBadge(
        ShadBadge.outline(
          child: Text(
            Strings.badgeRestricted,
            style: theme.textTheme.small.copyWith(
              color: AppColors.regulatoryAmber,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (member.isHospitalOnly) {
      addBadge(
        ShadBadge.secondary(
          backgroundColor: AppColors.regulatoryGray,
          child: Text(
            Strings.hospitalBadge,
            style: theme.textTheme.small.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (member.isDental) {
      addBadge(
        ShadBadge.secondary(
          backgroundColor: theme.colorScheme.secondary,
          child: Text(
            Strings.badgeDental,
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.secondaryForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (member.isOtc) {
      addBadge(
        ShadBadge(
          backgroundColor: AppColors.regulatoryGreen.withValues(alpha: 0.15),
          child: Text(
            Strings.badgeOtc,
            style: theme.textTheme.small.copyWith(
              color: AppColors.regulatoryGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (member.isSurveillance) {
      addBadge(
        ShadBadge.secondary(
          backgroundColor: AppColors.regulatoryYellow,
          child: Text(
            Strings.badgeSurveillance,
            style: theme.textTheme.small.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return badges;
  }

  Widget _buildActionBar(
    BuildContext context,
    ShadThemeData theme,
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
                        color: theme.colorScheme.destructive,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      color: theme.colorScheme.destructive.withValues(
                        alpha: 0.1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.triangleAlert,
                          size: AppDimens.iconSm,
                          color: theme.colorScheme.destructive,
                        ),
                        const Gap(AppDimens.spacingXs),
                        Text(
                          Strings.shortageAlert,
                          style: theme.textTheme.small.copyWith(
                            color: theme.colorScheme.destructive,
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
            child: ShadButton.secondary(
              onPressed: () => _launchUrl(context, ficheUrl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.info,
                    size: AppDimens.iconSm,
                    color: theme.colorScheme.secondaryForeground,
                  ),
                  const Gap(AppDimens.spacingXs),
                  Text(Strings.ficheInfo, style: theme.textTheme.small),
                ],
              ),
            ),
          ),
          const Gap(8),
          Expanded(
            child: ShadButton.outline(
              onPressed: () => _launchUrl(context, rcpUrl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.fileText,
                    size: AppDimens.iconSm,
                    color: theme.colorScheme.foreground,
                  ),
                  const Gap(AppDimens.spacingXs),
                  Text(Strings.rcpDocument, style: theme.textTheme.small),
                ],
              ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d\'ouvrir l\'URL: $url')),
        );
      }
    }
  }
}

class _GroupIdentityHeader extends StatelessWidget {
  const _GroupIdentityHeader({required this.viewModel});

  final GroupedProductsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final priceLabel = viewModel.priceLabel ?? Strings.priceUnavailable;
    final refundValue = viewModel.refundLabel ?? Strings.refundNotAvailable;
    final hasRefundData = viewModel.refundLabel != null;
    final conditionBadges = viewModel.aggregatedConditions
        .map((condition) => ConditionBadge.condition(context, condition))
        .whereType<Widget>()
        .toList();

    return ShadCard(
      padding: const EdgeInsets.all(AppDimens.spacingMd),
      backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.08),
      border: ShadBorder.all(
        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
        width: 1.2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            viewModel.metadata.title,
            style: theme.textTheme.h3.copyWith(fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Gap(AppDimens.spacingSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  priceLabel,
                  style: theme.textTheme.h3.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const Gap(AppDimens.spacingSm),
              Flexible(
                child: hasRefundData
                    ? ShadBadge.secondary(
                        child: Text(
                          '${Strings.refundLabel} · $refundValue',
                          style: theme.textTheme.small.copyWith(
                            color: theme.colorScheme.secondaryForeground,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      )
                    : ShadBadge.outline(
                        child: Text(
                          refundValue,
                          style: theme.textTheme.small,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
              ),
            ],
          ),
          if (conditionBadges.isNotEmpty) ...[
            const Gap(AppDimens.spacingSm),
            Wrap(
              spacing: AppDimens.spacing2xs,
              runSpacing: AppDimens.spacing2xs,
              children: conditionBadges,
            ),
          ],
        ],
      ),
    );
  }
}

enum _ProductSectionType { princeps, generics, related }
