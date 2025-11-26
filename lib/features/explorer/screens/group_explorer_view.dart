// lib/features/explorer/screens/group_explorer_view.dart
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/utils/dosage_utils.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/detail_item.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_back_header.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_badges.dart';
import 'package:pharma_scan/core/widgets/ui_kit/section_header.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/core/database/daos/library_dao.dart';
import 'package:pharma_scan/features/explorer/models/grouped_by_product_model.dart';
import 'package:pharma_scan/features/explorer/models/grouped_products_view_model.dart';
import 'package:pharma_scan/features/explorer/providers/group_classification_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class GroupExplorerView extends ConsumerWidget {
  final String groupId;

  const GroupExplorerView({required this.groupId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final groupDataAsync = ref.watch(groupDetailViewModelProvider(groupId));

    return groupDataAsync.when(
      data: (viewModel) {
        if (viewModel == null) {
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

        final groupData = viewModel.groupData;
        final GroupedProductsViewModel groupedData = viewModel;
        final princepsCount = viewModel.princepsPresentationCount;
        final genericsCount = viewModel.genericsPresentationCount;
        final relatedCount = viewModel.relatedPrincepsCount;

        return Scaffold(
          backgroundColor: theme.colorScheme.background,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildAppBarContent(
                    context,
                    theme,
                    groupData,
                    princepsCount,
                    genericsCount,
                    relatedCount,
                  ),
                ),
                _buildSectionHeader(
                  Strings.princeps,
                  groupedData.princeps.length,
                  icon: LucideIcons.star,
                ),
                _buildProductList(
                  groupedData.princeps,
                  sectionType: _ProductSectionType.princeps,
                ),
                _buildSectionHeader(
                  Strings.generics,
                  groupedData.generics.length,
                  icon: LucideIcons.copy,
                ),
                _buildProductList(
                  groupedData.generics,
                  sectionType: _ProductSectionType.generics,
                ),
                if (groupedData.relatedPrinceps.isNotEmpty) ...[
                  _buildSectionHeader(
                    Strings.relatedTherapies,
                    groupedData.relatedPrinceps.length,
                    icon: LucideIcons.link,
                  ),
                  _buildTherapiesList(groupedData.relatedPrinceps),
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
    ProductGroupData groupData,
    int princepsCount,
    int genericsCount,
    int relatedCount,
  ) {
    final metadataBadges = <Widget>[
      if (groupData.distinctDosages.isNotEmpty)
        ...groupData.distinctDosages.map(
          (dosage) => ShadBadge.outline(
            child: Text(
              '${Strings.dosagesLabel} $dosage',
              style: theme.textTheme.small,
            ),
          ),
        ),
      if (groupData.distinctFormulations.isNotEmpty)
        ...groupData.distinctFormulations.map(
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
      if (groupData.commonPrincipes.isNotEmpty)
        '${Strings.activeIngredientsLabel} : ${groupData.commonPrincipes.join(', ')}',
      if (relatedCount > 0) Strings.associatedPrincepsCount(relatedCount),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PharmaBackHeader(
          title: groupData.syntheticTitle,
          backLabel: Strings.backToSearch,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spacingMd,
            AppDimens.spacingSm,
            AppDimens.spacingMd,
            0,
          ),
          child: ShadCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.spacingMd,
              vertical: AppDimens.spacingSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  groupData.syntheticTitle,
                  style: theme.textTheme.h3,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (metadataBadges.isNotEmpty) ...[
                  const Gap(AppDimens.spacingSm),
                  Wrap(
                    spacing: AppDimens.spacingXs,
                    runSpacing: AppDimens.spacing2xs,
                    children: metadataBadges,
                  ),
                ],
                const Gap(AppDimens.spacingSm),
                for (final line in summaryLines)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppDimens.spacing2xs / 2,
                    ),
                    child: Text(line, style: theme.textTheme.muted),
                  ),
              ],
            ),
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

  Widget _buildProductList(
    List<GroupedByProduct> groupedProducts, {
    _ProductSectionType? sectionType,
  }) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingMd,
            vertical: AppDimens.spacing2xs,
          ),
          child: _buildGroupedProductCard(
            ShadTheme.of(context),
            groupedProducts[index],
            sectionType: sectionType,
          ),
        ),
        childCount: groupedProducts.length,
      ),
    );
  }

  // WHY: Builds a list of clickable therapy cards that navigate to their respective groups.
  Widget _buildTherapiesList(List<GroupedByProduct> relatedTherapies) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final therapy = relatedTherapies[index];
        // WHY: Get groupId from the first medicament in the group.
        final groupId = therapy.medicaments.isNotEmpty
            ? therapy.medicaments.first.groupId
            : null;

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spacingMd,
            vertical: AppDimens.spacing2xs,
          ),
          child: Semantics(
            button: true,
            label: Strings.associatedTherapySemantics(therapy.productName),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: groupId != null
                    ? () {
                        context.push(AppRoutes.groupDetail(groupId));
                      }
                    : null,
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                splashColor: ShadTheme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                highlightColor: ShadTheme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.05),
                child: _buildGroupedProductCard(
                  ShadTheme.of(context),
                  therapy,
                  sectionType: _ProductSectionType.related,
                ),
              ),
            ),
          ),
        );
      }, childCount: relatedTherapies.length),
    );
  }

  Widget _buildGroupedProductCard(
    ShadThemeData theme,
    GroupedByProduct product, {
    _ProductSectionType? sectionType,
  }) {
    final dosageLabel = _formatDosage(product.dosage, product.dosageUnit);
    final count = product.medicaments.length;
    final typeBadge = switch (sectionType) {
      _ProductSectionType.princeps => const PrincepsBadge(),
      _ProductSectionType.generics => const GenericBadge(),
      _ => null,
    };

    // WHY: Build subtitle with aggregated labs list, truncating if too long
    final displayedLabs = product.laboratories.take(3).join(', ');
    final remainingCount = product.laboratories.length > 3
        ? product.laboratories.length - 3
        : 0;
    final subtitleText = remainingCount > 0
        ? '${Strings.availableAt}$displayedLabs${Strings.andOthers(remainingCount)}'
        : '${Strings.availableAt}$displayedLabs';

    final forms = product.medicaments
        .map((med) => med.formePharmaceutique.trim())
        .where((form) => form.isNotEmpty)
        .toSet()
        .toList();

    final metadataBadges = <Widget>[
      if (dosageLabel != null)
        ShadBadge.outline(
          child: Text(
            '${Strings.dosage} $dosageLabel',
            style: theme.textTheme.small,
          ),
        ),
      ...forms.map(
        (form) => ShadBadge.secondary(
          child: Text(
            form,
            style: theme.textTheme.small.copyWith(
              color: theme.colorScheme.secondaryForeground,
            ),
          ),
        ),
      ),
    ];

    return ShadAccordion<String>(
      children: [
        ShadAccordionItem<String>(
          value: product.productName,
          title: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (typeBadge != null) ...[
                          typeBadge,
                          const Gap(AppDimens.spacingXs),
                        ],
                        Expanded(
                          child: Text(
                            product.productName,
                            style: theme.textTheme.p.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        const Gap(AppDimens.spacingXs),
                        ShadBadge.secondary(
                          child: Text(
                            count.toString(),
                            style: theme.textTheme.small,
                          ),
                        ),
                      ],
                    ),
                    const Gap(AppDimens.spacing2xs),
                    Text(
                      subtitleText,
                      style: theme.textTheme.muted,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (metadataBadges.isNotEmpty) ...[
                      const Gap(AppDimens.spacing2xs),
                      Wrap(
                        spacing: AppDimens.spacing2xs,
                        runSpacing: AppDimens.spacing2xs / 2,
                        children: metadataBadges,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: AppDimens.spacingXs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final med in product.medicaments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppDimens.spacingSm),
                    child: ShadAccordion<String>(
                      children: [
                        ShadAccordionItem<String>(
                          value: '${product.productName}_${med.codeCip}',
                          title: Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppDimens.spacingSm,
                            ),
                            child: _MedicamentListItem(medicament: med),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppDimens.spacingSm,
                            ),
                            child: _buildStructuredDetails(theme, med),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String? _formatDosage(Decimal? dosage, String? unit) {
    final normalizedUnit = unit?.trim() ?? '';
    if (dosage == null && normalizedUnit.isEmpty) return null;
    if (dosage == null) return normalizedUnit;

    final formatted = formatDecimal(dosage);
    return normalizedUnit.isEmpty ? formatted : '$formatted $normalizedUnit';
  }

  Widget _buildStructuredDetails(ShadThemeData theme, MedicationItem med) {
    final dosageLabel = med.formattedDosage;

    return ShadCard(
      padding: const EdgeInsets.all(AppDimens.spacingMd),
      backgroundColor: theme.colorScheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailItem(label: Strings.canonicalNameLabel, value: med.nom),
          const Gap(AppDimens.spacingXs),
          DetailItem(
            label: Strings.structuredDosageLabel,
            value: dosageLabel ?? Strings.notDefined,
          ),
          const Gap(AppDimens.spacingXs),
          DetailItem(
            label: Strings.officialFormulationLabel,
            value: med.formePharmaceutique.isNotEmpty
                ? med.formePharmaceutique
                : Strings.nonIdentified,
          ),
        ],
      ),
    );
  }
}

enum _ProductSectionType { princeps, generics, related }

class _MedicamentListItem extends StatelessWidget {
  const _MedicamentListItem({required this.medicament});

  final MedicationItem medicament;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final titulaire = medicament.titulaire.isNotEmpty
        ? medicament.titulaire
        : Strings.unknownHolder;
    final dosageLabel = medicament.formattedDosage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          medicament.nom,
          style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        const Gap(AppDimens.spacing2xs),
        Text(
          '${Strings.cip} ${medicament.codeCip}',
          style: theme.textTheme.muted,
        ),
        const Gap(AppDimens.spacing2xs / 2),
        Text(
          titulaire,
          style: theme.textTheme.small.copyWith(
            color: theme.textTheme.muted.color ??
                theme.textTheme.small.color ??
                theme.colorScheme.foreground.withValues(alpha: 0.6),
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        if (dosageLabel != null) ...[
          const Gap(AppDimens.spacing2xs / 2),
          Text(dosageLabel, style: theme.textTheme.small),
        ],
      ],
    );
  }
}
