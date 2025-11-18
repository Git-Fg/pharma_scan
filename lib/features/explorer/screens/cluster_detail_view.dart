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
        title: Text(
          princepsBrandName,
          style: theme.textTheme.h4,
        ),
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
                        'Aucun groupe n’est associé à ce cluster.',
                        style: theme.textTheme.muted,
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: groups.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final summary = groups[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          splashColor:
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                          highlightColor:
                              theme.colorScheme.primary.withValues(alpha: 0.05),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => GroupExplorerView(
                                  groupId: summary.groupId,
                                  onExit: () => Navigator.of(context).pop(),
                                ),
                              ),
                            );
                          },
                          child: ShadCard(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        summary.princepsReferenceName,
                                        style: theme.textTheme.h4,
                                      ),
                                    ),
                                    ShadBadge(
                                      child: Text(
                                        summary.groupId,
                                        style:
                                            theme.textTheme.small.copyWith(
                                          color: theme
                                              .colorScheme.primaryForeground,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Principe(s) actif(s)',
                                  style: theme.textTheme.small.copyWith(
                                    color: theme.colorScheme.mutedForeground,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  summary.commonPrincipes.isEmpty
                                      ? 'Non déterminé'
                                      : summary.commonPrincipes,
                                  style: theme.textTheme.p,
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ShadButton(
                                    onPressed: () {
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
                                    child: const Text('Explorer le groupe'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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

