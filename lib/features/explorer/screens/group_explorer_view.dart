// lib/features/explorer/screens/group_explorer_view.dart
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/core/utils/dosage_utils.dart';
import 'package:pharma_scan/features/explorer/models/grouped_by_product_model.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:pharma_scan/features/explorer/models/product_group_classification_model.dart';
import 'package:pharma_scan/features/explorer/widgets/medicament_card.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class GroupExplorerView extends StatefulWidget {
  final String groupId;
  final VoidCallback onExit;

  const GroupExplorerView({
    required this.groupId,
    required this.onExit,
    super.key,
  });

  @override
  State<GroupExplorerView> createState() => GroupExplorerViewState();
}

class GroupExplorerViewState extends State<GroupExplorerView> {
  final DatabaseService _dbService = sl<DatabaseService>();
  ProductGroupClassification? _classification;
  bool _isLoadingGroup = true;

  @override
  void initState() {
    super.initState();
    _loadGroupClassification(widget.groupId);
  }

  Future<void> _loadGroupClassification(String groupId) async {
    setState(() => _isLoadingGroup = true);
    final classification = await _dbService.classifyProductGroup(groupId);
    if (mounted) {
      setState(() {
        _classification = classification;
        _isLoadingGroup = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    if (_isLoadingGroup) {
      return const Scaffold(body: Center(child: ShadProgress()));
    }

    final classification = _classification;
    if (classification == null) {
      return const Scaffold(
        body: Center(child: Text('Impossible de charger les détails.')),
      );
    }

    final princepsCount = _countPresentations(classification.princeps);
    final genericsCount = _countPresentations(classification.generics);
    final relatedCount = _countPresentations(classification.relatedPrinceps);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildAppBarContent(
                theme,
                classification,
                princepsCount,
                genericsCount,
                relatedCount,
              ),
            ),
            _buildSectionHeader(
              theme,
              'Princeps',
              classification.princeps.length,
            ),
            _buildProductList(classification.princeps),
            _buildSectionHeader(
              theme,
              'Génériques',
              classification.generics.length,
            ),
            _buildProductList(classification.generics),
            if (classification.relatedPrinceps.isNotEmpty) ...[
              _buildSectionHeader(
                theme,
                'Thérapies Associées',
                classification.relatedPrinceps.length,
                icon: LucideIcons.link,
              ),
              _buildTherapiesList(classification.relatedPrinceps),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarContent(
    ShadThemeData theme,
    ProductGroupClassification classification,
    int princepsCount,
    int genericsCount,
    int relatedCount,
  ) {
    final summaryLines = <String>[
      '$princepsCount princeps • $genericsCount génériques',
      if (classification.commonActiveIngredients.isNotEmpty)
        'Principe(s) actif(s) : ${classification.commonActiveIngredients.join(', ')}',
      if (classification.distinctDosages.isNotEmpty)
        'Dosages : ${classification.distinctDosages.join(', ')}',
      if (classification.distinctFormulations.isNotEmpty)
        'Formes : ${classification.distinctFormulations.join(', ')}',
      '$relatedCount princeps associés',
    ];

    return ShadCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShadButton.outline(
            onPressed: widget.onExit,
            leading: const Icon(LucideIcons.arrowLeft, size: 16),
            child: const Text('Retour'),
          ),
          const SizedBox(height: 12),
          Text(
            classification.syntheticTitle,
            style: theme.textTheme.h3,
            overflow: TextOverflow.ellipsis,
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          for (final line in summaryLines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(line, style: theme.textTheme.muted),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    ShadThemeData theme,
    String title,
    int count, {
    IconData? icon,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: theme.colorScheme.mutedForeground),
              const SizedBox(width: 8),
            ],
            Text(title, style: theme.textTheme.h4),
            const SizedBox(width: 8),
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
            label: 'Thérapie associée: ${therapy.productName}',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: groupId != null
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => GroupExplorerView(
                              groupId: groupId,
                              onExit: () => Navigator.of(context).pop(),
                            ),
                          ),
                        );
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

    final subtitleText = '$count présentation(s) • Laboratoires: $labsLabel';

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
                    const SizedBox(height: 4),
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
                const SizedBox(width: 12),
                Text(dosageLabel, style: theme.textTheme.small),
              ],
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ShadAccordion<String>(
              children: [
                for (final med in product.medicaments)
                  ShadAccordionItem<String>(
                    value: '${product.productName}_${med.codeCip}',
                    title: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: MedicamentCard(medicament: med, hideDosage: true),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildStructuredDetails(theme, med),
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
    return formatDosageLabel(dosage: dosage, unit: unit);
  }

  Widget _buildStructuredDetails(ShadThemeData theme, Medicament med) {
    final dosageLabel = formatDosageLabel(
      dosage: med.dosage,
      unit: med.dosageUnit,
    );

    return ShadCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: theme.colorScheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ParsedDetailRow(
            label: 'Nom canonique (Base)',
            value: med.nom,
            theme: theme,
          ),
          const SizedBox(height: 8),
          _ParsedDetailRow(
            label: 'Dosage structuré',
            value: dosageLabel ?? 'Non défini',
            theme: theme,
          ),
          const SizedBox(height: 8),
          _ParsedDetailRow(
            label: 'Formulation officielle',
            value: med.formePharmaceutique ?? 'Non identifiée',
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _ParsedDetailRow extends StatelessWidget {
  const _ParsedDetailRow({
    required this.label,
    required this.value,
    required this.theme,
  });

  final String label;
  final String value;
  final ShadThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.small.copyWith(
            color: theme.colorScheme.mutedForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.p),
      ],
    );
  }
}
