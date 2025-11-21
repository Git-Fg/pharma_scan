// lib/features/explorer/screens/group_explorer_view.dart
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/core/utils/dosage_utils.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/detail_item.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_back_header.dart';
import 'package:pharma_scan/core/widgets/ui_kit/section_header.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/models/grouped_by_product_model.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:pharma_scan/features/explorer/models/product_group_classification_model.dart';
import 'package:pharma_scan/features/explorer/providers/group_classification_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class GroupExplorerView extends ConsumerWidget {
  final String groupId;

  const GroupExplorerView({required this.groupId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final classificationAsync = ref.watch(groupClassificationProvider(groupId));

    return classificationAsync.when(
      data: (classification) {
        if (classification == null) {
          return Scaffold(
            body: StatusView(
              type: StatusType.error,
              title: Strings.loadDetailsError,
              description: Strings.noGroupsForCluster,
              action: ShadButton(
                onPressed: () => context.pop(),
                child: const Text(Strings.back),
              ),
            ),
          );
        }

        final princepsCount = _countPresentations(classification.princeps);
        final genericsCount = _countPresentations(classification.generics);
        final relatedCount = _countPresentations(
          classification.relatedPrinceps,
        );

        return Scaffold(
          backgroundColor: theme.colorScheme.background,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildAppBarContent(
                    context,
                    theme,
                    classification,
                    princepsCount,
                    genericsCount,
                    relatedCount,
                  ),
                ),
                _buildSectionHeader(
                  Strings.princeps,
                  classification.princeps.length,
                ),
                _buildProductList(classification.princeps),
                _buildSectionHeader(
                  Strings.generics,
                  classification.generics.length,
                ),
                _buildProductList(classification.generics),
                if (classification.relatedPrinceps.isNotEmpty) ...[
                  _buildSectionHeader(
                    Strings.relatedTherapies,
                    classification.relatedPrinceps.length,
                    icon: LucideIcons.link,
                  ),
                  _buildTherapiesList(classification.relatedPrinceps),
                ],
                const SliverToBoxAdapter(child: Gap(24)),
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
                ref.invalidate(groupClassificationProvider(groupId)),
            child: const Text(Strings.retry),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarContent(
    BuildContext context,
    ShadThemeData theme,
    ProductGroupClassification classification,
    int princepsCount,
    int genericsCount,
    int relatedCount,
  ) {
    final summaryLines = <String>[
      Strings.summaryLine(princepsCount, genericsCount),
      if (classification.commonActiveIngredients.isNotEmpty)
        '${Strings.activeIngredientsLabel} : ${classification.commonActiveIngredients.join(', ')}',
      if (classification.distinctDosages.isNotEmpty)
        '${Strings.dosagesLabel} ${classification.distinctDosages.join(', ')}',
      if (classification.distinctFormulations.isNotEmpty)
        '${Strings.formsLabel} ${classification.distinctFormulations.join(', ')}',
      Strings.associatedPrincepsCount(relatedCount),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PharmaBackHeader(
          title: classification.syntheticTitle,
          backLabel: Strings.backToSearch,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ShadCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in summaryLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
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

  Widget _buildProductList(List<GroupedByProduct> groupedProducts) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: _buildGroupedProductCard(
            ShadTheme.of(context),
            groupedProducts[index],
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                borderRadius: BorderRadius.circular(12),
                splashColor: ShadTheme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                highlightColor: ShadTheme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.05),
                child: _buildGroupedProductCard(ShadTheme.of(context), therapy),
              ),
            ),
          ),
        );
      }, childCount: relatedTherapies.length),
    );
  }

  int _countPresentations(List<GroupedByProduct> products) {
    return products.fold<int>(
      0,
      (total, group) => total + group.medicaments.length,
    );
  }

  Widget _buildGroupedProductCard(
    ShadThemeData theme,
    GroupedByProduct product,
  ) {
    final labsLabel = product.laboratories.join(', ');
    final dosageLabel = _formatDosage(product.dosage, product.dosageUnit);
    final count = product.medicaments.length;

    // WHY: Truncate long lab names to prevent overflow
    final truncatedLabs = labsLabel.length > 50
        ? '${labsLabel.substring(0, 47)}...'
        : labsLabel;
    final subtitleText = Strings.presentationSubtitle(count, truncatedLabs);

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
                    Text(
                      product.productName,
                      style: theme.textTheme.p.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const Gap(4),
                    Text(
                      subtitleText,
                      style: theme.textTheme.muted,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              if (dosageLabel != null) ...[
                const Gap(12),
                Text(dosageLabel, style: theme.textTheme.small),
              ],
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final med in product.medicaments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ShadAccordion<String>(
                      children: [
                        ShadAccordionItem<String>(
                          value: '${product.productName}_${med.codeCip}',
                          title: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MedicamentListItem(medicament: med),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
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

  Widget _buildStructuredDetails(ShadThemeData theme, Medicament med) {
    final dosageLabel = med.formattedDosage;

    return ShadCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: theme.colorScheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailItem(label: Strings.canonicalNameLabel, value: med.nom),
          const Gap(8),
          DetailItem(
            label: Strings.structuredDosageLabel,
            value: dosageLabel ?? Strings.notDefined,
          ),
          const Gap(8),
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

class _MedicamentListItem extends StatelessWidget {
  const _MedicamentListItem({required this.medicament});

  final Medicament medicament;

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
        const Gap(4),
        Text(
          '${Strings.cip} ${medicament.codeCip}',
          style: theme.textTheme.muted,
        ),
        const Gap(2),
        Text(
          titulaire,
          style: theme.textTheme.small,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        if (dosageLabel != null) ...[
          const Gap(2),
          Text(dosageLabel, style: theme.textTheme.small),
        ],
      ],
    );
  }
}
