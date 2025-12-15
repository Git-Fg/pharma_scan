import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/cluster_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Drawer widget to display detailed medication content for a cluster
/// Uses lazy loading to fetch content only when opened
class MedicationDrawer extends ConsumerWidget {
  const MedicationDrawer({
    required this.clusterId,
    super.key,
  });

  final String clusterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(clusterContentProvider(clusterId));
    final spacing = context.spacing;

    return ShadSheet(
      title: const Text("Détail du groupe"),
      child: productsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        data: (products) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.md,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: products.length,
            separatorBuilder: (context, index) => Gap(spacing.xs),
            itemBuilder: (ctx, idx) {
              final product = products[idx];
              return ProductRow(
                name: product.name,
                isPrinceps: product.isPrinceps,
                cisCode: product.cisCode,
              );
            },
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.triangleAlert,
                color: context.colors.destructive,
                size: 48,
              ),
              Gap(spacing.sm),
              Text(
                Strings.errorLoadingCluster,
                style: context.typo.p,
              ),
              Gap(spacing.xs),
              Text(
                error.toString(),
                style: context.typo.small.copyWith(
                  color: context.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual row representing a product in the cluster
class ProductRow extends StatelessWidget {
  const ProductRow({
    required this.name,
    required this.isPrinceps,
    required this.cisCode,
    super.key,
  });

  final String name;
  final bool isPrinceps;
  final String cisCode; // For potential navigation to details

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Container(
      padding: EdgeInsets.all(spacing.sm),
      decoration: BoxDecoration(
        color: isPrinceps ? context.colors.secondary : context.colors.card,
        borderRadius: context.shadTheme.radius,
        border: Border.all(
          color: isPrinceps ? context.colors.primary : context.colors.border,
        ),
      ),
      child: Row(
        children: [
          if (isPrinceps)
            ShadBadge(
              child: Text(
                Strings.princeps,
                style: context.typo.small,
              ),
            ),
          Gap(spacing.xs),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.typo.p.copyWith(
                fontWeight: isPrinceps ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension Strings on String {
  static String get errorLoadingCluster => "Erreur de chargement du cluster";
  static String get princeps => "Princeps";
}
