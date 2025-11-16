// lib/features/explorer/screens/database_screen.dart
import 'package:flutter/material.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_summary_model.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:pharma_scan/core/locator.dart';
import 'package:pharma_scan/core/services/database_service.dart';
import 'package:pharma_scan/features/explorer/models/group_details_model.dart';
import 'package:pharma_scan/features/scanner/models/medicament_model.dart';
import 'package:pharma_scan/features/scanner/models/scan_result_model.dart';

enum SortOption { name, dosage }

enum ViewMode { genericToPrinceps, princepsToGeneric }

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
  Map<String, dynamic>? _stats;
  List<Medicament> _searchResults = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final DatabaseService _dbService = sl<DatabaseService>();

  GroupDetails? _groupDetails;
  bool _isLoadingGroup = false;
  SortOption _sortOption = SortOption.name;
  ViewMode _viewMode = ViewMode.genericToPrinceps;

  // Local state for filter and new default view
  bool _showAllProducts = false;
  List<GenericGroupSummary> _genericGroupSummaries = [];
  bool _isLoadingSummaries = false;

  @override
  void initState() {
    super.initState();
    if (widget.groupIdToExplore != null) {
      _loadGroupDetails(widget.groupIdToExplore!);
    } else {
      _loadStats();
      _loadGroupSummaries();
    }
  }

  @override
  void didUpdateWidget(covariant DatabaseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.groupIdToExplore != null &&
        widget.groupIdToExplore != oldWidget.groupIdToExplore) {
      _loadGroupDetails(widget.groupIdToExplore!);
    } else if (widget.groupIdToExplore == null && _groupDetails != null) {
      _exitGroupMode();
      // Reload default view data when exiting group mode
      if (_genericGroupSummaries.isEmpty) {
        _loadGroupSummaries();
      }
    }
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
    final summaries = await _dbService.getGenericGroupSummaries();
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
      // Sort after setting the details
      _sortLists();
    }
  }

  void _exitGroupMode() {
    widget.onClearGroup();
    setState(() {
      _groupDetails = null;
      _isLoadingGroup = false;
      _sortOption = SortOption.name;
    });
  }

  void _setSortOption(SortOption option) {
    setState(() {
      _sortOption = option;
      _sortLists();
    });
  }

  void _sortLists() {
    if (_groupDetails == null) return;

    // Create mutable copies of the lists to avoid modifying immutable freezed lists
    final sortedPrinceps = List<Medicament>.from(_groupDetails!.princeps);
    final sortedGenerics = List<Medicament>.from(_groupDetails!.generics);

    sortedPrinceps.sort(_getComparison);
    sortedGenerics.sort(_getComparison);

    // Update the state with a new GroupDetails containing sorted lists
    setState(() {
      _groupDetails = GroupDetails(
        princeps: sortedPrinceps,
        generics: sortedGenerics,
      );
    });
  }

  int _getComparison(Medicament a, Medicament b) {
    if (_sortOption == SortOption.dosage) {
      // WHY: On utilise le champ dosage structuré au lieu d'extraire depuis le nom.
      // Les médicaments sans dosage sont placés en fin de liste.
      final dosageA = a.dosage ?? double.infinity;
      final dosageB = b.dosage ?? double.infinity;
      return dosageA.compareTo(dosageB);
    }
    return a.nom.compareTo(b.nom);
  }

  void _showDetails(Medicament basicMedicament) async {
    // WHY: Fetch full details including status (Generic vs Princeps)
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

    if (_groupDetails != null) {
      return _buildGroupMode();
    }

    return _buildSearchMode();
  }

  Widget _buildSearchMode() {
    final theme = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
        child: Text('Aucun groupe à afficher.', style: theme.textTheme.muted),
      );
    }
    return ShadTable(
      columnCount: 2,
      rowCount: _genericGroupSummaries.length,
      header: (context, column) {
        if (column == 0) {
          return const ShadTableCell.header(child: Text('Générique (Groupe)'));
        }
        return const ShadTableCell.header(child: Text('Princeps de référence'));
      },
      columnSpanExtent: (index) {
        if (index == 0) {
          return const FixedTableSpanExtent(180);
        }
        return const RemainingTableSpanExtent();
      },
      builder: (context, index) {
        final summary = _genericGroupSummaries[index.row];
        if (index.column == 0) {
          return ShadTableCell(
            child: Text(
              summary.commonPrincipes, // Utilise directement la donnée propre
              style: theme.textTheme.p,
            ),
          );
        }
        return ShadTableCell(
          child: summary.princepsNames.isEmpty
              ? Text('N/A', style: theme.textTheme.muted)
              : Text(
                  summary.princepsNames.join(', '),
                  style: theme.textTheme.p,
                ),
        );
      },
    );
  }

  Widget _buildGroupMode() {
    final theme = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
              child: Row(
                children: [
                  ShadButton.outline(
                    onPressed: _exitGroupMode,
                    leading: const Icon(LucideIcons.arrowLeft, size: 16),
                    child: const Text('Retour'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Détails du Groupe',
                      style: theme.textTheme.h4,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 16),
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
            Expanded(
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
          ],
        ),
      ),
    );
  }

  Widget _buildGroupColumn(
    ShadThemeData theme,
    String title,
    List<Medicament> medicaments,
  ) {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(title, style: theme.textTheme.h4),
          ),
          ShadSeparator.horizontal(),
          Expanded(
            child: ListView.separated(
              itemCount: medicaments.length,
              separatorBuilder: (context, index) => ShadSeparator.horizontal(),
              itemBuilder: (context, index) {
                final med = medicaments[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med.nom, style: theme.textTheme.p),
                      Text(
                        med.codeCip,
                        style: theme.textTheme.small.copyWith(
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
