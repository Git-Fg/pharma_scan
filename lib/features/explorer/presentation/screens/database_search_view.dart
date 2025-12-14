import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pharma_scan/core/hooks/use_app_header.dart';
import 'package:pharma_scan/core/hooks/use_tab_reselection.dart';
import 'package:pharma_scan/core/services/data_initialization_service.dart';
import 'package:pharma_scan/core/theme/app_dimens.dart';
import 'package:pharma_scan/core/theme/theme_extensions.dart';
import 'package:pharma_scan/core/utils/strings.dart';
import 'package:pharma_scan/core/widgets/ui_kit/status_view.dart';
import 'package:pharma_scan/features/explorer/presentation/providers/cluster_provider.dart';
import 'package:pharma_scan/features/explorer/presentation/widgets/cluster_tile.dart'
    hide Strings;
import 'package:pharma_scan/features/explorer/presentation/widgets/medication_drawer.dart'
    hide Strings;
import 'package:pharma_scan/features/home/providers/initialization_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DatabaseSearchView extends HookConsumerWidget {
  const DatabaseSearchView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    final debouncedQuery = useState('');
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottomPadding = MediaQuery.paddingOf(context).bottom;
    final bottomSpace =
        viewInsetsBottom > 0 ? viewInsetsBottom : safeBottomPadding;
    final listBottomPadding =
        AppDimens.searchBarHeaderHeight + bottomSpace + AppDimens.spacingSm;

    // Setup tab reselection with standard ScrollController for explorer tab (index 1)
    final scrollController = useScrollController();
    useTabReselection(
      ref: ref,
      controller: scrollController,
      tabIndex: 1,
    );

    final currentQuery = debouncedQuery.value;
    final clusterResults = ref.watch(clusterSearchProvider(currentQuery));
    final initStepAsync = ref.watch(initializationStepProvider);

    final initStep = initStepAsync.value;
    if (initStep != null &&
        initStep != InitializationStep.ready &&
        initStep != InitializationStep.error) {
      return const Center(
        child: StatusView(
          type: StatusType.loading,
          icon: LucideIcons.loader,
          title: Strings.initializationInProgress,
          description: Strings.initializationDescription,
        ),
      );
    }

    useAppHeader(
      title: Text(
        Strings.explorer,
        style: context.typo.h4,
      ),
    );

    return Column(
      children: [
        Expanded(
          child: clusterResults.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.triangleAlert,
                    color: Colors.red,
                    size: 48,
                  ),
                  const Gap(AppDimens.spacingSm),
                  Text(
                    'Erreur de chargement',
                    style: context.typo.p,
                  ),
                  const Gap(AppDimens.spacingXs),
                  Text(
                    error.toString(),
                    style: context.typo.small.copyWith(
                      color: context.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            data: (clusters) => ListView.builder(
              itemCount: clusters.length,
              padding: EdgeInsets.only(bottom: listBottomPadding),
              controller: scrollController,
              itemBuilder: (context, index) {
                final cluster = clusters[index];
                return ClusterTile(
                  title: cluster.title, // Display title (Substance Clean)
                  subtitle:
                      cluster.subtitle, // Display subtitle (Princeps Principal)
                  countProducts: cluster.countProducts ?? 0,
                  onTap: () => _openDrawer(context, cluster.clusterId),
                );
              },
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: AppDimens.spacingMd,
              right: AppDimens.spacingMd,
              bottom:
                  viewInsetsBottom > 0 ? viewInsetsBottom : AppDimens.spacingSm,
            ),
            child: ShadInput(
              placeholder: const Text('Rechercher...'),
              onChanged: (String query) => debouncedQuery.value = query,
            ),
          ),
        ),
      ],
    );
  }
}

/// Utility function to open medication drawer
void _openDrawer(BuildContext context, String clusterId) {
  showShadSheet(
    context: context,
    side: ShadSheetSide.bottom,
    builder: (context) => MedicationDrawer(clusterId: clusterId),
  );
}
