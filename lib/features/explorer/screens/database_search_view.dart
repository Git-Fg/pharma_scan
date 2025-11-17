// lib/features/explorer/screens/database_search_view.dart
import 'package:flutter/material.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_summary_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/features/explorer/models/explorer_enums.dart';
import 'package:pharma_scan/features/explorer/widgets/medicament_card.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';

class DatabaseSearchView extends StatefulWidget {
  final Function(String) onGroupSelected;

  const DatabaseSearchView({required this.onGroupSelected, super.key});

  @override
  State<DatabaseSearchView> createState() => DatabaseSearchViewState();
}

class DatabaseSearchViewState extends State<DatabaseSearchView> {
  Map<String, dynamic>? _stats;
  List<Medicament> _searchResults = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _dbService = sl<DatabaseService>();

  bool _showAllProducts = false;
  List<GenericGroupSummary> _genericGroupSummaries = [];
  bool _isLoadingSummaries = false;

  // Pagination state
  int _currentOffset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  late ScrollController _scrollController;
  late ScrollController _searchScrollController;
  static const int _pageSize = 50;

  FormCategory _selectedCategory = FormCategory.oral;

  final Map<FormCategory, List<String>> _categoryKeywords = {
    FormCategory.oral: [
      'comprimé',
      'gélule',
      'capsule',
      'lyophilisat',
      'comprimé orodispersible',
      'film orodispersible',
      'gomme',
      'gomme à mâcher',
      'pastille',
      'pastille à sucer',
      'plante pour tisane',
      'plantes pour tisane',
      'plante(s) pour tisane',
      'mélange de plantes pour tisane',
      'plante en vrac',
    ],
    FormCategory.syrup: ['sirop', 'suspension buvable'],
    FormCategory.drinkableDrops: [
      'solution buvable',
      'gouttes buvables',
      'solution en gouttes',
      'solution gouttes',
    ],
    FormCategory.sachet: [
      'sachet',
      'poudre pour solution buvable',
      'poudre pour suspension buvable',
      'granulé',
      'granules',
      'granulés',
      'poudre',
    ],
    FormCategory.injectable: [
      'injectable',
      'injection',
      'perfusion',
      'solution pour perfusion',
      'poudre pour solution injectable',
      'solution pour injection',
      'dispersion pour perfusion',
      'usage parentéral',
      'parentéral',
      'poudre et solvant',
      'générateur radiopharmaceutique',
      'précurseur radiopharmaceutique',
      'solution pour dialyse',
      'solution pour hémofiltration',
      'solution pour instillation',
      'solution cardioplégique',
      'solution pour administration intravésicale',
      'suspension pour instillation',
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
      'patch',
      'patchs',
      'emplâtre',
      'compresse',
      'bâton pour application',
      'mousse pour application',
      'mousse',
      'pansement',
      'implant',
      'shampooing',
      'solution filmogène pour application',
      'dispositif pour application',
      'solution pour application',
      'solution moussant',
      'solution pour lavage',
      'suppositoire',
    ],
    FormCategory.ophthalmic: [
      'collyre',
      'ophtalmique',
      'solution ophtalmique',
      'pommade ophtalmique',
      'gel ophtalmique',
      'solution pour irrigation oculaire',
    ],
    FormCategory.nasalOrl: [
      'nasale',
      'auriculaire',
      'buccale',
      'aérosol',
      'spray nasal',
      'gouttes nasales',
      'gouttes auriculaires',
      'bain de bouche',
      'collutoire',
      'gaz pour inhalation',
      'gaz',
      'cartouche pour inhalation',
      'dispersion pour inhalation',
      'inhalation',
      'insert',
      'solution pour pulvérisation',
    ],
    FormCategory.other:
        [], // Formes non classées - logique spéciale dans DatabaseService
  };

  final Map<FormCategory, List<String>> _categoryExclusions = {
    FormCategory.oral: ['buvable', 'solution', 'suspension'],
    FormCategory.syrup: [],
    FormCategory.drinkableDrops: [],
    FormCategory.sachet: ['injectable', 'injection', 'parentéral', 'solvant'],
    FormCategory.injectable: [],
    FormCategory.gynecological: [],
    FormCategory.externalUse: ['vaginal', 'vaginale'],
    FormCategory.ophthalmic: [],
    FormCategory.nasalOrl: [],
    FormCategory.other: [],
  };

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _searchScrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadStats();
    _loadGroupSummaries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await _dbService.getDatabaseStats();
    if (mounted) {
      setState(() => _stats = stats);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_isLoadingMore &&
        !_isLoadingSummaries) {
      _loadMoreGroupSummaries();
    }
  }

  Future<void> _loadGroupSummaries({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoadingSummaries = true;
        _currentOffset = 0;
        _hasMore = true;
        _genericGroupSummaries = [];
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      // Special handling for "other" category: exclude all other categories' keywords
      List<String>? formKeywords;
      List<String>? excludeKeywords;

      if (_selectedCategory == FormCategory.other) {
        // Collect all keywords from all other categories
        final allOtherKeywords = <String>[];
        for (final category in FormCategory.values) {
          if (category != FormCategory.other) {
            allOtherKeywords.addAll(_categoryKeywords[category] ?? []);
          }
        }
        formKeywords =
            []; // Empty - we want forms that don't match any category
        excludeKeywords = allOtherKeywords;
      } else {
        formKeywords = _categoryKeywords[_selectedCategory];
        excludeKeywords = _categoryExclusions[_selectedCategory];
      }

      final summaries = await _dbService.getGenericGroupSummaries(
        formKeywords: formKeywords,
        excludeKeywords: excludeKeywords,
        limit: _pageSize,
        offset: _currentOffset,
      );

      if (mounted) {
        setState(() {
          if (loadMore) {
            _genericGroupSummaries.addAll(summaries);
            _currentOffset += summaries.length;
            _hasMore = summaries.length == _pageSize;
            _isLoadingMore = false;
          } else {
            _genericGroupSummaries = summaries;
            _currentOffset = summaries.length;
            _hasMore = summaries.length == _pageSize;
            _isLoadingSummaries = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (loadMore) {
            _isLoadingMore = false;
          } else {
            _isLoadingSummaries = false;
          }
        });
      }
    }
  }

  Future<void> _loadMoreGroupSummaries() async {
    if (!_hasMore || _isLoadingMore) return;
    await _loadGroupSummaries(loadMore: true);
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
    return Scrollbar(
      controller: _searchScrollController,
      thumbVisibility: true,
      child: ListView.separated(
        controller: _searchScrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _searchResults.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final med = _searchResults[index];
          return MedicamentCard(
            medicament: med,
            onTap: () => _showDetails(med),
            trailing: ShadTooltip(
              builder: (context) => const Text('Ouvrir les détails'),
              child: ShadIconButton.ghost(
                icon: const Icon(LucideIcons.chevronRight, size: 16),
                onPressed: () => _showDetails(med),
              ),
            ),
          );
        },
      ),
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
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _genericGroupSummaries.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) {
        if (index == _genericGroupSummaries.length) {
          return const SizedBox.shrink();
        }
        return const SizedBox(height: 12);
      },
      itemBuilder: (context, index) {
        if (index == _genericGroupSummaries.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: const ShadProgress(),
              ),
            ),
          );
        }
        final summary = _genericGroupSummaries[index];
        return Semantics(
          button: true,
          label:
              'Groupe ${summary.princepsReferenceName}, principes actifs ${summary.commonPrincipes}',
          child: Material(
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
                          Text(
                            summary.commonPrincipes,
                            style: theme.textTheme.p,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(
                        LucideIcons.arrowRight,
                        color: theme.colorScheme.mutedForeground,
                      ),
                    ),
                    Expanded(
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
                            summary.princepsReferenceName,
                            style: theme.textTheme.p.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
              FormCategory.syrup,
              'Sirop',
              LucideIcons.droplet,
            ),
            const SizedBox(width: 8),
            _buildFilterButton(
              theme,
              FormCategory.drinkableDrops,
              'Gouttes',
              LucideIcons.beaker,
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
            const SizedBox(width: 8),
            _buildFilterButton(
              theme,
              FormCategory.other,
              'Autre',
              LucideIcons.ellipsis,
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
