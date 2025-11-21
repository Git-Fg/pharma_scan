// lib/features/explorer/screens/cluster_detail_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:pharma_scan/core/router/app_routes.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/pharma_back_header.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/models/generic_group_summary_model.dart';
import 'package:pharma_scan/features/explorer/providers/group_cluster_provider.dart';
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
      body: SafeArea(
        child: Column(
          children: [
            PharmaBackHeader(
              title: princepsBrandName,
              backLabel: Strings.backToClusters,
            ),
            Expanded(
              child: Padding(
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
                            Strings.sharedActiveIngredients,
                            style: theme.textTheme.small.copyWith(
                              color: theme.colorScheme.mutedForeground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Gap(8),
                          Text(
                            activeIngredients.isEmpty
                                ? Strings.notDetermined
                                : activeIngredients.join(', '),
                            style: theme.textTheme.p,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 3,
                          ),
                          const Gap(12),
                          ShadBadge.secondary(
                            child: Text(
                              '${Strings.cluster} $clusterKey',
                              style: theme.textTheme.small,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(16),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return clusterGroups.when(
                            data: (groups) {
                              if (groups.isEmpty) {
                                return const StatusView(
                                  type: StatusType.empty,
                                  title: Strings.noGroupsForCluster,
                                );
                              }

                              return ListView.separated(
                                itemCount: groups.length,
                                separatorBuilder: (context, index) =>
                                    const Gap(12),
                                itemBuilder: (context, index) {
                                  final entity = groups[index];
                                  final summary = GenericGroupSummary(
                                    groupId: entity.groupId,
                                    commonPrincipes: entity.commonPrincipes,
                                    princepsReferenceName:
                                        entity.princepsReferenceName,
                                  );
                                  return _ClusterGroupCard(
                                    theme: theme,
                                    summary: summary,
                                  );
                                },
                              );
                            },
                            loading: () =>
                                const StatusView(type: StatusType.loading),
                            error: (error, stackTrace) {
                              return StatusView(
                                type: StatusType.error,
                                title: Strings.errorLoadingGroups,
                                description: error.toString(),
                                action: Semantics(
                                  button: true,
                                  label: Strings.retryLoadingGroups,
                                  child: ShadButton(
                                    onPressed: () => ref.invalidate(
                                      clusterGroupsProvider(clusterKey),
                                    ),
                                    child: const Text(Strings.retry),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClusterGroupCard extends StatelessWidget {
  const _ClusterGroupCard({required this.theme, required this.summary});

  final ShadThemeData theme;
  final GenericGroupSummary summary;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          'Groupe ${summary.groupId}, princeps ${summary.princepsReferenceName}, principes actifs ${summary.commonPrincipes.isEmpty ? "non déterminé" : summary.commonPrincipes}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push(AppRoutes.groupDetail(summary.groupId)),
          child: ShadCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShadBadge(
                      child: Text(
                        summary.groupId,
                        style: theme.textTheme.small.copyWith(
                          color: theme.colorScheme.primaryForeground,
                        ),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Text(
                        summary.princepsReferenceName,
                        style: theme.textTheme.p.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Gap(8),
                    Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ],
                ),
                const Gap(12),
                Text(
                  Strings.activePrinciplesLabel,
                  style: theme.textTheme.small.copyWith(
                    color: theme.colorScheme.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(4),
                Text(
                  summary.commonPrincipes.isEmpty
                      ? Strings.notDetermined
                      : summary.commonPrincipes,
                  style: theme.textTheme.p,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
