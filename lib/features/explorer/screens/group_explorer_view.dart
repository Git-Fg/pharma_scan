// lib/features/explorer/screens/group_explorer_view.dart
import 'package:flutter/material.dart';
import 'package:pharma_scan/core/utils/medicament_helpers.dart';
import 'package:pharma_scan/features/explorer/models/grouped_by_laboratory_model.dart';
import 'package:pharma_scan/features/explorer/models/grouped_by_product_model.dart';
import 'package:pharma_scan/features/explorer/widgets/medicament_card.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/features/explorer/models/explorer_enums.dart';
import 'package:pharma_scan/features/explorer/models/group_details_model.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';

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
  GroupDetails? _groupDetails;
  bool _isLoadingGroup = true;
  SortOption _sortOption = SortOption.name;
  String _groupTitle = 'Détails du Groupe';

  @override
  void initState() {
    super.initState();
    _loadGroupDetails(widget.groupId);
  }

  Future<void> _loadGroupDetails(String groupId) async {
    setState(() => _isLoadingGroup = true);
    final details = await _dbService.getGroupDetails(groupId);
    if (mounted) {
      setState(() {
        _groupDetails = details;
        _groupTitle = _deriveGroupTitle(details);
        _isLoadingGroup = false;
        _sortLists();
      });
    }
  }

  String _deriveGroupTitle(GroupDetails details) {
    if (details.princeps.isNotEmpty) {
      return cleanGroupLabel(details.princeps.first.nom);
    }
    if (details.generics.isNotEmpty &&
        details.generics.first.products.isNotEmpty) {
      return cleanGroupLabel(details.generics.first.products.first.nom);
    }
    return 'Groupe Inconnu';
  }

  void _setSortOption(SortOption option) {
    setState(() {
      _sortOption = option;
      _sortLists();
    });
  }

  void _sortLists() {
    if (_groupDetails == null) return;

    final sortedPrinceps = List<Medicament>.from(_groupDetails!.princeps)
      ..sort(_getComparison);
    final sortedRelatedPrinceps = List<Medicament>.from(
      _groupDetails!.relatedPrinceps,
    )..sort(_getComparison);

    // Sort products within each group, then sort groups by laboratory name
    // This maintains the grouping structure while ensuring products are sorted
    final sortedGenerics = _groupDetails!.generics.map((group) {
      final sortedProducts = List<Medicament>.from(group.products)
        ..sort(_getComparison);
      return GroupedByLaboratory(
        laboratory: group.laboratory,
        products: sortedProducts,
      );
    }).toList()..sort((a, b) => a.laboratory.compareTo(b.laboratory));

    setState(() {
      _groupDetails = GroupDetails(
        princeps: sortedPrinceps,
        generics: sortedGenerics,
        relatedPrinceps: sortedRelatedPrinceps,
      );
    });
  }

  int _getComparison(Medicament a, Medicament b) {
    if (_sortOption == SortOption.dosage) {
      final dosageA = a.dosage ?? double.infinity;
      final dosageB = b.dosage ?? double.infinity;
      final comparison = dosageA.compareTo(dosageB);
      if (comparison != 0) return comparison;
    }
    return a.nom.compareTo(b.nom);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    if (_isLoadingGroup) {
      return const Scaffold(body: Center(child: ShadProgress()));
    }

    final details = _groupDetails;
    if (details == null) {
      return const Scaffold(
        body: Center(child: Text('Impossible de charger les détails.')),
      );
    }

    final groupedProducts = _groupGenericsByProduct(details.generics);
    final totalGenerics = groupedProducts.length;
    final totalMeds = details.princeps.length + totalGenerics;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _buildAppBarContent(
                theme,
                totalMeds,
                details.relatedPrinceps.length,
              ),
            ),
            _buildSectionHeader(theme, 'Princeps', details.princeps.length),
            _buildPrincepsList(details.princeps),
            _buildSectionHeader(theme, 'Génériques', totalGenerics),
            _buildGenericsList(groupedProducts),
            if (details.relatedPrinceps.isNotEmpty) ...[
              _buildSectionHeader(
                theme,
                'Princeps Associés',
                details.relatedPrinceps.length,
                icon: LucideIcons.link,
              ),
              _buildPrincepsList(details.relatedPrinceps),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBarContent(
    ShadThemeData theme,
    int totalMeds,
    int relatedCount,
  ) {
    return ShadCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShadButton.outline(
                onPressed: widget.onExit,
                leading: const Icon(LucideIcons.arrowLeft, size: 16),
                child: const Text('Retour'),
              ),
              const Spacer(),
              ShadSelect<SortOption>(
                initialValue: _sortOption,
                onChanged: (value) {
                  if (value != null) _setSortOption(value);
                },
                options: const [
                  ShadOption(
                    value: SortOption.name,
                    child: Text('Trier par Nom'),
                  ),
                  ShadOption(
                    value: SortOption.dosage,
                    child: Text('Trier par Dosage'),
                  ),
                ],
                selectedOptionBuilder: (context, value) {
                  return Text(value == SortOption.name ? 'Nom' : 'Dosage');
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_groupTitle, style: theme.textTheme.h3),
          const SizedBox(height: 4),
          Text(
            '$totalMeds médicaments dans ce groupe • $relatedCount princeps associés',
            style: theme.textTheme.muted,
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

  Widget _buildPrincepsList(List<Medicament> princeps) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: MedicamentCard(medicament: princeps[index]),
        ),
        childCount: princeps.length,
      ),
    );
  }

  Widget _buildGenericsList(List<GroupedByProduct> groupedProducts) {
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

  List<GroupedByProduct> _groupGenericsByProduct(
    List<GroupedByLaboratory> generics,
  ) {
    final Map<String, _ProductAggregation> aggregation = {};

    for (final group in generics) {
      for (final medicament in group.products) {
        final key = _productKey(medicament);
        final entry = aggregation.putIfAbsent(
          key,
          () => _ProductAggregation(
            productName: medicament.nom,
            dosage: medicament.dosage,
            dosageUnit: medicament.dosageUnit,
          ),
        );

        final lab = (medicament.titulaire?.trim().isNotEmpty ?? false)
            ? medicament.titulaire!.trim()
            : 'Laboratoire Inconnu';

        entry.laboratories.add(lab);
        entry.codeCips.add(medicament.codeCip);
      }
    }

    final groupedProducts = aggregation.values.map((entry) {
      final laboratories = entry.laboratories.toList()..sort();
      final codeCips = entry.codeCips.toList();

      return GroupedByProduct(
        productName: entry.productName,
        dosage: entry.dosage,
        dosageUnit: entry.dosageUnit,
        laboratories: laboratories,
        codeCips: codeCips,
      );
    }).toList()..sort(_compareProducts);

    return groupedProducts;
  }

  int _compareProducts(GroupedByProduct a, GroupedByProduct b) {
    if (_sortOption == SortOption.dosage) {
      final dosageA = a.dosage ?? double.infinity;
      final dosageB = b.dosage ?? double.infinity;
      final comparison = dosageA.compareTo(dosageB);
      if (comparison != 0) return comparison;
    }
    return a.productName.compareTo(b.productName);
  }

  String _productKey(Medicament medicament) {
    final dosage = medicament.dosage?.toString() ?? 'null';
    final unit = medicament.dosageUnit ?? 'null';
    return '${medicament.nom.toUpperCase()}|$dosage|$unit';
  }

  Widget _buildGroupedProductCard(
    ShadThemeData theme,
    GroupedByProduct product,
  ) {
    final labsLabel = product.laboratories.join(', ');
    final dosageLabel = _formatDosage(product.dosage, product.dosageUnit);

    return ShadCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.productName,
            style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w500),
          ),
          if (dosageLabel != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  LucideIcons.activity,
                  size: 14,
                  color: theme.colorScheme.mutedForeground,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    dosageLabel,
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.building2,
                size: 14,
                color: theme.colorScheme.mutedForeground,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Laboratoires disponibles : $labsLabel',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _formatDosage(double? dosage, String? unit) {
    if (dosage == null && unit == null) return null;
    if (dosage == null) return unit;
    if (unit == null) return _formatNumber(dosage);
    return '${_formatNumber(dosage)} $unit';
  }

  String _formatNumber(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}

class _ProductAggregation {
  _ProductAggregation({
    required this.productName,
    required this.dosage,
    required this.dosageUnit,
  });

  final String productName;
  final double? dosage;
  final String? dosageUnit;
  final Set<String> laboratories = <String>{};
  final Set<String> codeCips = <String>{};
}
