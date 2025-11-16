// lib/features/explorer/screens/database_screen.dart
import 'package:flutter/material.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_summary_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/features/explorer/models/group_details_model.dart';
import 'package:pharma_scan/features/explorer/models/grouped_generic_model.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';

enum SortOption { name, dosage }

enum ViewMode { genericToPrinceps, princepsToGeneric }

enum FormCategory {
  injectable,
  gynecological,
  externalUse,
  sachet,
  oral,
  ophthalmic,
  nasalOrl,
}

class _DatabaseSearchView extends StatefulWidget {
  final Function(String) onGroupSelected;

  const _DatabaseSearchView({required this.onGroupSelected});

  @override
  State<_DatabaseSearchView> createState() => _DatabaseSearchViewState();
}

class _DatabaseSearchViewState extends State<_DatabaseSearchView> {
  Map<String, dynamic>? _stats;
  List<Medicament> _searchResults = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _dbService = sl<DatabaseService>();

  bool _showAllProducts = false;
  List<GenericGroupSummary> _genericGroupSummaries = [];
  bool _isLoadingSummaries = false;

  FormCategory _selectedCategory = FormCategory.oral;

  final Map<FormCategory, List<String>> _categoryKeywords = {
    FormCategory.injectable: [
      'injectable',
      'injection',
      'perfusion',
      'solution pour perfusion',
      'poudre pour solution injectable',
      'solution pour injection',
    ],
    FormCategory.gynecological: [
      'ovule',
      'pessaire',
      'comprimé vaginal',
      'crème vaginale',
      'gel vaginal',
      'capsule vaginale',
      'tampon vaginal',
      'anneau vaginal',
    ],
    FormCategory.externalUse: [
      'crème',
      'pommade',
      'gel',
      'lotion',
      'pâte',
      'cutanée',
      'cutané',
      'application locale',
      'application cutanée',
      'dispositif transdermique',
    ],
    FormCategory.sachet: [
      'sachet',
      'poudre pour solution buvable',
      'poudre pour suspension buvable',
      'granulé',
    ],
    FormCategory.oral: [
      'comprimé',
      'gélule',
      'capsule',
      'lyophilisat',
      'solution buvable',
      'sirop',
      'suspension buvable',
      'comprimé orodispersible',
    ],
    FormCategory.ophthalmic: [
      'collyre',
      'ophtalmique',
      'solution ophtalmique',
      'pommade ophtalmique',
      'gel ophtalmique',
    ],
    FormCategory.nasalOrl: [
      'nasale',
      'auriculaire',
      'buccale',
      'aérosol',
      'spray nasal',
      'gouttes nasales',
      'gouttes auriculaires',
    ],
  };

  final Map<FormCategory, List<String>> _categoryExclusions = {
    FormCategory.injectable: [],
    FormCategory.gynecological: [],
    FormCategory.externalUse: ['vaginal', 'vaginale'],
    FormCategory.sachet: ['injectable', 'injection'],
    FormCategory.oral: [
      'injectable',
      'injection',
      'vaginal',
      'vaginale',
      'sachet',
    ],
    FormCategory.ophthalmic: [],
    FormCategory.nasalOrl: [],
  };

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadGroupSummaries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await _dbService.getDatabaseStats();
    if (mounted) {
      setState(() => _stats = stats);
    }
  }

  Future<void> _loadGroupSummaries() async {
    setState(() => _isLoadingSummaries = true);

    final summaries = await _dbService.getGenericGroupSummaries(
      formKeywords: _categoryKeywords[_selectedCategory],
      excludeKeywords: _categoryExclusions[_selectedCategory],
      limit: 500,
    );

    if (mounted) {
      setState(() {
        _genericGroupSummaries = summaries;
        _isLoadingSummaries = false;
      });
    }
  }

  void _toggleFilter() {
    setState(() {
      _showAllProducts = !_showAllProducts;
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await _dbService.searchMedicaments(
      query,
      showAll: _showAllProducts,
    );
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _showDetails(Medicament basicMedicament) async {
    final result = await _dbService.getScanResultByCip(basicMedicament.codeCip);

    if (!mounted) return;

    showShadSheet(
      side: ShadSheetSide.bottom,
      context: context,
      builder: (context) {
        final theme = ShadTheme.of(context);

        if (result == null) {
          return ShadSheet(
            title: const Text('Détails non disponibles'),
            description: const Text('Impossible de charger les détails.'),
            actions: [
              ShadButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          );
        }

        return result.when(
          generic: (medicament, associatedPrinceps, groupId) {
            return _buildSheetContent(
              context,
              'GÉNÉRIQUE',
              theme.colorScheme.primary,
              medicament,
              associatedPrinceps: associatedPrinceps,
            );
          },
          princeps: (princeps, moleculeName, genericLabs, groupId) {
            return _buildSheetContent(
              context,
              'PRINCEPS',
              theme.colorScheme.secondary,
              princeps,
              associatedGenerics: [],
            );
          },
        );
      },
    );
  }

  Widget _buildSheetContent(
    BuildContext context,
    String badgeText,
    Color badgeColor,
    Medicament medicament, {
    List<Medicament>? associatedGenerics,
    List<Medicament>? associatedPrinceps,
  }) {
    final theme = ShadTheme.of(context);
    return ShadSheet(
      title: Row(
        children: [
          ShadBadge(
            backgroundColor: badgeColor,
            child: Text(
              badgeText,
              style: TextStyle(
                color: badgeColor == theme.colorScheme.primary
                    ? theme.colorScheme.primaryForeground
                    : theme.colorScheme.secondaryForeground,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              medicament.nom,
              style: theme.textTheme.h4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      description: Text('CIP: ${medicament.codeCip}'),
      actions: [
        ShadButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: associatedGenerics != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Génériques Associés (${associatedGenerics.length}):',
                    style: theme.textTheme.lead,
                  ),
                  const SizedBox(height: 8),
                  ...associatedGenerics.map(
                    (g) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• ${g.nom}', style: theme.textTheme.p),
                    ),
                  ),
                ],
              )
            : associatedPrinceps != null && associatedPrinceps.isNotEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Princeps Associé(s) (${associatedPrinceps.length}):',
                    style: theme.textTheme.lead,
                  ),
                  const SizedBox(height: 8),
                  ...associatedPrinceps.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• ${p.nom}', style: theme.textTheme.p),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Principes Actifs:', style: theme.textTheme.lead),
                  const SizedBox(height: 8),
                  ...medicament.principesActifs.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $p', style: theme.textTheme.p),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              child: Column(
                children: [
                  if (_stats != null) _buildStatsHeader(theme),
                  const SizedBox(height: 16),
                  _buildSearchBar(theme),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _isSearching
                        ? Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 300),
                              child: const ShadProgress(),
                            ),
                          )
                        : _searchController.text.isNotEmpty
                        ? _buildSearchResults(theme)
                        : _buildGroupSummaryView(theme),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildFormFilterButtons(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(ShadThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(theme, 'Princeps', '${_stats!['total_princeps']}'),
          _buildStatItem(theme, 'Génériques', '${_stats!['total_generiques']}'),
          _buildStatItem(
            theme,
            'Principes Actifs',
            '${_stats!['total_principes']}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(ShadThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(value, style: theme.textTheme.h4),
        Text(label, style: theme.textTheme.muted),
      ],
    );
  }

  Widget _buildSearchBar(ShadThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: ShadInput(
            controller: _searchController,
            placeholder: const Text('Rechercher par nom, CIP, ou principe...'),
            onChanged: _performSearch,
          ),
        ),
        const SizedBox(width: 8),
        ShadTooltip(
          builder: (context) =>
              const Text('Afficher/Cacher les produits non-médicaments'),
          child: ShadButton.ghost(
            onPressed: _toggleFilter,
            leading: Icon(
              LucideIcons.funnel,
              size: 20,
              color: _showAllProducts
                  ? theme.colorScheme.primary
                  : theme.colorScheme.mutedForeground,
            ),
            child: const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(ShadThemeData theme) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text('Aucun résultat trouvé.', style: theme.textTheme.muted),
      );
    }
    return ShadTable(
      columnCount: 3,
      rowCount: _searchResults.length,
      header: (context, column) {
        if (column == 0) {
          return const ShadTableCell.header(child: Text('Nom du médicament'));
        } else if (column == 1) {
          return const ShadTableCell.header(child: Text('CIP'));
        } else {
          return const ShadTableCell.header(
            alignment: Alignment.centerRight,
            child: Text(''),
          );
        }
      },
      builder: (context, index) {
        final med = _searchResults[index.row];
        if (index.column == 0) {
          return ShadTableCell(child: Text(med.nom, style: theme.textTheme.p));
        } else if (index.column == 1) {
          return ShadTableCell(
            child: Text(med.codeCip, style: theme.textTheme.muted),
          );
        } else {
          return ShadTableCell(
            alignment: Alignment.centerRight,
            child: ShadIconButton.ghost(
              icon: const Icon(LucideIcons.chevronRight, size: 16),
              onPressed: () => _showDetails(med),
            ),
          );
        }
      },
    );
  }

  Widget _buildGroupSummaryView(ShadThemeData theme) {
    if (_isLoadingSummaries) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: const ShadProgress(),
        ),
      );
    }
    if (_genericGroupSummaries.isEmpty) {
      return Center(
        child: Text(
          'Aucun groupe à afficher pour cette catégorie.',
          style: theme.textTheme.muted,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _genericGroupSummaries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final summary = _genericGroupSummaries[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => widget.onGroupSelected(summary.groupId),
            borderRadius: BorderRadius.circular(12),
            splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
            child: ShadCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Principe(s) Actif(s)',
                          style: theme.textTheme.small.copyWith(
                            color: theme.colorScheme.mutedForeground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(summary.commonPrincipes, style: theme.textTheme.p),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Princeps de Référence',
                          style: theme.textTheme.small.copyWith(
                            color: theme.colorScheme.mutedForeground,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          summary.princepsNames.join(', '),
                          style: theme.textTheme.muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFormFilterButtons(ShadThemeData theme) {
    return ShadCard(
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterButton(
              theme,
              FormCategory.oral,
              'Oral',
              LucideIcons.pill,
            ),
            const SizedBox(width: 8),
            _buildFilterButton(
              theme,
              FormCategory.sachet,
              'Sachet',
              LucideIcons.package,
            ),
            const SizedBox(width: 8),
            _buildFilterButton(
              theme,
              FormCategory.injectable,
              'Injectable',
              LucideIcons.syringe,
            ),
            const SizedBox(width: 8),
            _buildFilterButton(
              theme,
              FormCategory.externalUse,
              'Externe',
              LucideIcons.circleDot,
            ),
            const SizedBox(width: 8),
            _buildFilterButton(
              theme,
              FormCategory.ophthalmic,
              'Yeux',
              LucideIcons.eye,
            ),
            const SizedBox(width: 8),
            _buildFilterButton(
              theme,
              FormCategory.nasalOrl,
              'ORL',
              LucideIcons.ear,
            ),
            const SizedBox(width: 8),
            _buildFilterButton(
              theme,
              FormCategory.gynecological,
              'Gynéco',
              LucideIcons.heart,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(
    ShadThemeData theme,
    FormCategory category,
    String label,
    IconData icon,
  ) {
    final isSelected = _selectedCategory == category;
    return ShadButton(
      onPressed: () {
        if (!isSelected) {
          setState(() {
            _selectedCategory = category;
          });
          _loadGroupSummaries();
        }
      },
      backgroundColor: isSelected
          ? theme.colorScheme.primary
          : Colors.transparent,
      foregroundColor: isSelected
          ? theme.colorScheme.primaryForeground
          : theme.colorScheme.foreground,
      leading: Icon(icon, size: 16),
      child: Text(label),
    );
  }
}

class _GroupExplorerView extends StatefulWidget {
  final String groupId;
  final VoidCallback onExit;

  const _GroupExplorerView({required this.groupId, required this.onExit});

  @override
  State<_GroupExplorerView> createState() => _GroupExplorerViewState();
}

class _GroupExplorerViewState extends State<_GroupExplorerView> {
  final DatabaseService _dbService = sl<DatabaseService>();
  GroupDetails? _groupDetails;
  bool _isLoadingGroup = false;
  SortOption _sortOption = SortOption.name;
  ViewMode _viewMode = ViewMode.genericToPrinceps;

  @override
  void initState() {
    super.initState();
    _loadGroupDetails(widget.groupId);
  }

  Future<void> _loadGroupDetails(String groupId) async {
    setState(() {
      _isLoadingGroup = true;
      _groupDetails = null;
    });
    final details = await _dbService.getGroupDetails(groupId);
    if (mounted) {
      setState(() {
        _groupDetails = details;
        _isLoadingGroup = false;
      });
      _sortLists();
    }
  }

  void _setSortOption(SortOption option) {
    setState(() {
      _sortOption = option;
      _sortLists();
    });
  }

  void _toggleViewMode() {
    setState(() {
      _viewMode = _viewMode == ViewMode.genericToPrinceps
          ? ViewMode.princepsToGeneric
          : ViewMode.genericToPrinceps;
    });
  }

  void _sortLists() {
    if (_groupDetails == null) return;

    final sortedPrinceps = List<Medicament>.from(_groupDetails!.princeps);
    final sortedGenerics = List<GroupedGeneric>.from(_groupDetails!.generics);
    final sortedRelatedPrinceps = List<Medicament>.from(
      _groupDetails!.relatedPrinceps,
    );

    sortedPrinceps.sort(_getComparison);
    sortedRelatedPrinceps.sort(_getComparison);

    // Sort the grouped generics list by base name
    sortedGenerics.sort((a, b) => a.baseName.compareTo(b.baseName));

    // Sort the products within each group according to the selected option
    // Create new GroupedGeneric instances with sorted products
    final sortedGenericsWithProducts = sortedGenerics.map((group) {
      final sortedProducts = List<Medicament>.from(group.products);
      sortedProducts.sort(_getComparison);
      return GroupedGeneric(baseName: group.baseName, products: sortedProducts);
    }).toList();

    setState(() {
      _groupDetails = GroupDetails(
        princeps: sortedPrinceps,
        generics: sortedGenericsWithProducts,
        relatedPrinceps: sortedRelatedPrinceps,
      );
    });
  }

  int _getComparison(Medicament a, Medicament b) {
    if (_sortOption == SortOption.dosage) {
      final dosageA = a.dosage ?? double.infinity;
      final dosageB = b.dosage ?? double.infinity;
      return dosageA.compareTo(dosageB);
    }
    return a.nom.compareTo(b.nom);
  }

  void _showDetails(Medicament basicMedicament) async {
    final result = await _dbService.getScanResultByCip(basicMedicament.codeCip);

    if (!mounted) return;

    showShadSheet(
      side: ShadSheetSide.bottom,
      context: context,
      builder: (context) {
        final theme = ShadTheme.of(context);

        if (result == null) {
          return ShadSheet(
            title: const Text('Détails non disponibles'),
            description: const Text('Impossible de charger les détails.'),
            actions: [
              ShadButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          );
        }

        return result.when(
          generic: (medicament, associatedPrinceps, groupId) {
            return _buildSheetContent(
              context,
              'GÉNÉRIQUE',
              theme.colorScheme.primary,
              medicament,
              associatedPrinceps: associatedPrinceps,
            );
          },
          princeps: (princeps, moleculeName, genericLabs, groupId) {
            return _buildSheetContent(
              context,
              'PRINCEPS',
              theme.colorScheme.secondary,
              princeps,
              associatedGenerics: [],
            );
          },
        );
      },
    );
  }

  Widget _buildSheetContent(
    BuildContext context,
    String badgeText,
    Color badgeColor,
    Medicament medicament, {
    List<Medicament>? associatedGenerics,
    List<Medicament>? associatedPrinceps,
  }) {
    final theme = ShadTheme.of(context);
    return ShadSheet(
      title: Row(
        children: [
          ShadBadge(
            backgroundColor: badgeColor,
            child: Text(
              badgeText,
              style: TextStyle(
                color: badgeColor == theme.colorScheme.primary
                    ? theme.colorScheme.primaryForeground
                    : theme.colorScheme.secondaryForeground,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              medicament.nom,
              style: theme.textTheme.h4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      description: Text('CIP: ${medicament.codeCip}'),
      actions: [
        ShadButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: associatedGenerics != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Génériques Associés (${associatedGenerics.length}):',
                    style: theme.textTheme.lead,
                  ),
                  const SizedBox(height: 8),
                  ...associatedGenerics.map(
                    (g) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• ${g.nom}', style: theme.textTheme.p),
                    ),
                  ),
                ],
              )
            : associatedPrinceps != null && associatedPrinceps.isNotEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Princeps Associé(s) (${associatedPrinceps.length}):',
                    style: theme.textTheme.lead,
                  ),
                  const SizedBox(height: 8),
                  ...associatedPrinceps.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• ${p.nom}', style: theme.textTheme.p),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Principes Actifs:', style: theme.textTheme.lead),
                  const SizedBox(height: 8),
                  ...medicament.principesActifs.map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $p', style: theme.textTheme.p),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingGroup) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: const ShadProgress(),
          ),
        ),
      );
    }

    if (_groupDetails == null) {
      return const SizedBox.shrink();
    }

    final theme = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            ShadCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  ShadButton.outline(
                    onPressed: widget.onExit,
                    leading: const Icon(LucideIcons.arrowLeft, size: 16),
                    child: const Text('Retour'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Détails du Groupe', style: theme.textTheme.h4),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            ShadBadge(
                              backgroundColor: theme.colorScheme.muted,
                              child: Text(
                                '${_groupDetails!.princeps.length + _groupDetails!.generics.length} médicaments',
                                style: theme.textTheme.small.copyWith(
                                  color: theme.colorScheme.mutedForeground,
                                ),
                              ),
                            ),
                            if (_groupDetails!.relatedPrinceps.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              ShadBadge(
                                backgroundColor: theme.colorScheme.muted,
                                child: Text(
                                  '+ ${_groupDetails!.relatedPrinceps.length} princeps associés',
                                  style: theme.textTheme.small.copyWith(
                                    color: theme.colorScheme.mutedForeground,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ShadTooltip(
                    builder: (context) => const Text('Inverser la vue'),
                    child: ShadIconButton.ghost(
                      icon: const Icon(LucideIcons.repeat, size: 20),
                      onPressed: _toggleViewMode,
                    ),
                  ),
                  const SizedBox(width: 8),
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
            ),
            const SizedBox(height: 16),
            Expanded(
              flex: 3,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _viewMode == ViewMode.genericToPrinceps
                    ? [
                        _buildGroupColumn(
                          theme,
                          'Génériques',
                          _groupDetails!.generics,
                        ),
                        const VerticalDivider(),
                        _buildGroupColumn(
                          theme,
                          'Princeps',
                          _groupDetails!.princeps,
                        ),
                      ]
                    : [
                        _buildGroupColumn(
                          theme,
                          'Princeps',
                          _groupDetails!.princeps,
                        ),
                        const VerticalDivider(),
                        _buildGroupColumn(
                          theme,
                          'Génériques',
                          _groupDetails!.generics,
                        ),
                      ],
              ),
            ),
            if (_groupDetails!.relatedPrinceps.isNotEmpty)
              _buildRelatedPrincepsSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupColumn(
    ShadThemeData theme,
    String title,
    List<dynamic> items,
  ) {
    final isPrinceps = title == 'Princeps';
    final medicaments = isPrinceps ? items.cast<Medicament>() : <Medicament>[];
    final groupedGenerics = !isPrinceps
        ? items.cast<GroupedGeneric>()
        : <GroupedGeneric>[];

    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                ShadBadge(
                  backgroundColor: isPrinceps
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.primary,
                  child: Text(
                    title,
                    style: theme.textTheme.small.copyWith(
                      color: isPrinceps
                          ? theme.colorScheme.secondaryForeground
                          : theme.colorScheme.primaryForeground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ShadBadge(
                  backgroundColor: theme.colorScheme.muted,
                  child: Text(
                    '${items.length}',
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ShadSeparator.horizontal(),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Aucun $title', style: theme.textTheme.muted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (isPrinceps) {
                        final med = medicaments[index];
                        return _buildMedicamentCard(theme, med, isPrinceps);
                      } else {
                        final group = groupedGenerics[index];
                        return _buildGroupedGenericCard(theme, group);
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicamentCard(
    ShadThemeData theme,
    Medicament med,
    bool isPrinceps,
  ) {
    return ShadCard(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: () => _showDetails(med),
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    med.nom,
                    style: theme.textTheme.p.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ShadIconButton.ghost(
                  icon: const Icon(LucideIcons.chevronRight, size: 16),
                  onPressed: () => _showDetails(med),
                ),
              ],
            ),
            if (med.dosage != null || med.dosageUnit != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    LucideIcons.pill,
                    size: 14,
                    color: theme.colorScheme.mutedForeground,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    med.dosage != null
                        ? '${med.dosage} ${med.dosageUnit ?? ''}'.trim()
                        : med.dosageUnit ?? '',
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ],
            if (med.titulaire != null && med.titulaire!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    LucideIcons.building2,
                    size: 14,
                    color: theme.colorScheme.mutedForeground,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      med.titulaire!,
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  LucideIcons.barcode,
                  size: 14,
                  color: theme.colorScheme.mutedForeground,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    med.codeCip,
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedGenericCard(ShadThemeData theme, GroupedGeneric group) {
    return ShadCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.baseName,
            style: theme.textTheme.p.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.products.map((med) {
              return ShadBadge(
                backgroundColor: theme.colorScheme.muted,
                child: Text(
                  med.titulaire ?? 'Labo Inconnu',
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedPrincepsSection(ShadThemeData theme) {
    return Expanded(
      flex: 2,
      child: ShadCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ShadBadge(
                    backgroundColor: theme.colorScheme.secondary,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.link, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Autres dosages / princeps de la même molécule',
                          style: theme.textTheme.small.copyWith(
                            color: theme.colorScheme.secondaryForeground,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ShadBadge(
                    backgroundColor: theme.colorScheme.muted,
                    child: Text(
                      '${_groupDetails!.relatedPrinceps.length}',
                      style: theme.textTheme.small.copyWith(
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ShadSeparator.horizontal(),
            Expanded(
              child: _groupDetails!.relatedPrinceps.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Aucun princeps associé',
                          style: theme.textTheme.muted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _groupDetails!.relatedPrinceps.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final med = _groupDetails!.relatedPrinceps[index];
                        return _buildMedicamentCard(theme, med, true);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class DatabaseScreen extends StatefulWidget {
  final String? groupIdToExplore;
  final VoidCallback onClearGroup;

  const DatabaseScreen({
    this.groupIdToExplore,
    required this.onClearGroup,
    super.key,
  });

  @override
  State<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<DatabaseScreen> {
  String? _currentGroupId;

  @override
  void initState() {
    super.initState();
    _currentGroupId = widget.groupIdToExplore;
  }

  @override
  void didUpdateWidget(covariant DatabaseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.groupIdToExplore != _currentGroupId) {
      setState(() {
        _currentGroupId = widget.groupIdToExplore;
      });
    }
  }

  void _handleGroupSelected(String groupId) {
    setState(() {
      _currentGroupId = groupId;
    });
  }

  void _handleExitGroup() {
    setState(() {
      _currentGroupId = null;
    });
    widget.onClearGroup();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentGroupId != null) {
      return _GroupExplorerView(
        groupId: _currentGroupId!,
        onExit: _handleExitGroup,
      );
    }

    return _DatabaseSearchView(onGroupSelected: _handleGroupSelected);
  }
}
