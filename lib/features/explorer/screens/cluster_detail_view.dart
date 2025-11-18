// lib/features/explorer/screens/cluster_detail_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pharma_scan/features/explorer/providers/group_cluster_provider.dart';
import 'package:pharma_scan/features/explorer/screens/group_explorer_view.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ClusterDetailView extends ConsumerWidget {
  const ClusterDetailView({
    super.key,
    required this.clusterKey,
    required this.princepsBrandName,
    required this.activeIngredients,
  });

  final String clusterKey;
  final String princepsBrandName;
  final List<String> activeIngredients;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final clusterGroups = ref.watch(clusterGroupsProvider(clusterKey));

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.foreground),
        title: Text(princepsBrandName, style: theme.textTheme.h4),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShadCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Principe(s) actif(s) partagés',
                    style: theme.textTheme.small.copyWith(
                      color: theme.colorScheme.mutedForeground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activeIngredients.isEmpty
                        ? 'Non déterminé'
                        : activeIngredients.join(', '),
                    style: theme.textTheme.p,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  ShadBadge.secondary(
                    child: Text(
                      'Cluster $clusterKey',
                      style: theme.textTheme.small,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: clusterGroups.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return Center(
                      child: Text(
                        'Aucun groupe n\'est associé à ce cluster.',
                        style: theme.textTheme.muted,
                      ),
                    );
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width - 32,
                      ),
                      child: ShadTable.list(
                        header: [
                          ShadTableCell.header(
                            child: Text(
                              'Groupe ID',
                              style: theme.textTheme.table,
                            ),
                          ),
                          ShadTableCell.header(
                            child: Text(
                              'Princeps',
                              style: theme.textTheme.table,
                            ),
                          ),
                          ShadTableCell.header(
                            child: Text(
                              'Principes Actifs',
                              style: theme.textTheme.table,
                            ),
                          ),
                        ],
                        children: groups.map((summary) {
                          return [
                            ShadTableCell(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  splashColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  highlightColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.05),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => GroupExplorerView(
                                          groupId: summary.groupId,
                                          onExit: () =>
                                              Navigator.of(context).pop(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 12,
                                    ),
                                    child: ShadBadge(
                                      child: Text(
                                        summary.groupId,
                                        style: theme.textTheme.small.copyWith(
                                          color: theme
                                              .colorScheme
                                              .primaryForeground,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ShadTableCell(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  splashColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  highlightColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.05),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => GroupExplorerView(
                                          groupId: summary.groupId,
                                          onExit: () =>
                                              Navigator.of(context).pop(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      summary.princepsReferenceName,
                                      style: theme.textTheme.p,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ShadTableCell(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  splashColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  highlightColor: theme.colorScheme.primary
                                      .withValues(alpha: 0.05),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => GroupExplorerView(
                                          groupId: summary.groupId,
                                          onExit: () =>
                                              Navigator.of(context).pop(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      summary.commonPrincipes.isEmpty
                                          ? 'Non déterminé'
                                          : summary.commonPrincipes,
                                      style: theme.textTheme.p,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ];
                        }).toList(),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: ShadProgress()),
                error: (error, stackTrace) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: ShadCard(
                      title: Text(
                        'Impossible de charger les groupes',
                        style: theme.textTheme.h4,
                      ),
                      description: Text(
                        error.toString(),
                        style: theme.textTheme.muted,
                      ),
                      footer: Align(
                        alignment: Alignment.centerRight,
                        child: ShadButton(
                          onPressed: () =>
                              ref.invalidate(clusterGroupsProvider(clusterKey)),
                          child: const Text('Réessayer'),
                        ),
                      ),
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
